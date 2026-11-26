// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import ApplicationServices
import SwiftUI

/// One menu bar icon as the Settings page and the dropdown show it.
struct MenuBarManagedItem: Identifiable {
    let id: String
    let bundleID: String
    let appName: String
    let title: String
    /// Set for the system's own icons, which share one generic app icon.
    let symbolName: String?

    var appIcon: NSImage? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first?.icon
    }
}

/// A dropdown of every menu bar icon, grouped into the person's categories,
/// behind one arrow in the menu bar, the way Windows gathers its tray icons.
/// Nothing is hidden or moved: clicking an icon in the dropdown clicks the
/// real one. Icons are read and opened through Accessibility. Main thread only.
final class MenuBarManagerService: NSObject, ObservableObject {
    static let shared = MenuBarManagerService()

    @Published private(set) var isRunning = false
    @Published private(set) var items: [MenuBarManagedItem] = []
    @Published private(set) var isScanning = false
    @Published private(set) var layout = MenuBarCategoryLayout()

    private var toggleItem: NSStatusItem?
    private var popover: NSPopover?
    private var entries: [String: MenuBarItemScanner.Entry] = [:]
    private let scanQueue = DispatchQueue(label: "com.vorssaint.menu-bar-manager.scan", qos: .userInitiated)

    private var defaults: UserDefaults { .standard }

    /// The feature is offered on macOS 27 and later only.
    static var isSupported: Bool {
        if #available(macOS 27, *) { return true }
        return false
    }

    private override init() {
        super.init()
    }

    // MARK: Lifecycle

    func syncWithPreferences() {
        let stored = MenuBarManagerSupport.decodeLayout(
            defaults.string(forKey: DefaultsKey.menuBarManagerCategories) ?? "")
        if stored != layout { layout = stored }
        guard AppFeature.menuBarManager.isAvailable, Self.isSupported,
              defaults.bool(forKey: DefaultsKey.menuBarManagerEnabled) else {
            stop()
            return
        }
        start()
    }

    private func start() {
        guard !isRunning else { return }
        isRunning = true
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = MenuBarManagerSupport.toggleAutosaveName
        item.isVisible = true
        if let button = item.button {
            let title = FeatureStrings.menuBarManager(L10n.shared.language).openDropdown
            let image = NSImage(systemSymbolName: "chevron.down.circle", accessibilityDescription: title)
            image?.isTemplate = true
            button.image = image
            button.toolTip = title
            button.target = self
            button.action = #selector(toggleClicked(_:))
        }
        toggleItem = item
    }

    private func stop() {
        guard isRunning else { return }
        isRunning = false
        popover?.performClose(nil)
        popover = nil
        if let toggleItem { NSStatusBar.system.removeStatusItem(toggleItem) }
        toggleItem = nil
    }

    // MARK: Categories

    func updateLayout(_ change: (inout MenuBarCategoryLayout) -> Void) {
        var next = layout
        change(&next)
        next = MenuBarManagerSupport.sanitized(next)
        guard next != layout else { return }
        layout = next
        defaults.set(MenuBarManagerSupport.encodeLayout(next), forKey: DefaultsKey.menuBarManagerCategories)
    }

    // MARK: The dropdown

    @objc private func toggleClicked(_ sender: Any?) {
        if let popover, popover.isShown {
            popover.performClose(nil)
            return
        }
        guard let button = toggleItem?.button else { return }
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuBarCategoriesPanel())
        self.popover = popover
        refreshItems()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    func closeDropdown() {
        popover?.performClose(nil)
    }

    // MARK: Listing

    /// Reads every app's menu bar icons again.
    func refreshItems() {
        guard AXIsProcessTrusted() else {
            items = []
            entries = [:]
            return
        }
        isScanning = true
        let apps = MenuBarItemScanner.runningApps()
        scanQueue.async { [weak self] in
            let found = MenuBarItemScanner.scan(apps)
            DispatchQueue.main.async {
                guard let self else { return }
                self.absorb(found)
                self.isScanning = false
            }
        }
    }

    private func absorb(_ found: [MenuBarItemScanner.Entry]) {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        var nextEntries: [String: MenuBarItemScanner.Entry] = [:]
        var nextItems: [MenuBarManagedItem] = []
        for entry in found where entry.app.pid != ownPID {
            guard let bundleID = entry.app.bundleID, !bundleID.isEmpty,
                  entry.frame.width > 4, Self.isOnSomeDisplay(entry.frame) else { continue }
            let key = MenuBarManagerSupport.itemKey(bundleID: bundleID, appName: entry.app.name,
                                                    identifier: entry.identifier, index: entry.index)
            guard nextEntries[key] == nil else { continue }
            nextEntries[key] = entry
            nextItems.append(MenuBarManagedItem(
                id: key, bundleID: bundleID, appName: entry.app.name,
                title: MenuBarManagerSupport.displayTitle(title: entry.title, description: entry.description,
                                                          appName: entry.app.name),
                symbolName: bundleID == MenuBarManagerSupport.menuBarAgentBundleID
                    ? MenuBarManagerSupport.systemSymbol(forIdentifier: entry.identifier) : nil))
        }
        entries = nextEntries
        items = nextItems
    }

    /// Accessibility keeps reporting a frame for an icon it no longer draws,
    /// sometimes on no display at all.
    private static func isOnSomeDisplay(_ frame: CGRect) -> Bool {
        var capacity: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &capacity) == .success, capacity > 0 else { return false }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(capacity))
        var found: UInt32 = 0
        guard CGGetActiveDisplayList(capacity, &displays, &found) == .success else { return false }
        let center = CGPoint(x: frame.midX, y: frame.midY)
        return displays.prefix(Int(found)).contains { CGDisplayBounds($0).contains(center) }
    }

    // MARK: Opening an icon

    /// Opens an icon as a click on it would: clicked where it is drawn, or
    /// pressed through Accessibility when it is not drawn, such as one the
    /// system folded behind its overflow control.
    func activate(_ item: MenuBarManagedItem) {
        closeDropdown()
        guard let entry = entries[item.id] else {
            NSSound.beep()
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            // Let the dropdown close before the click lands.
            usleep(150_000)
            if let frame = MenuBarItemScanner.frame(of: entry.element),
               frame.width > 4, Self.isOnSomeDisplay(frame) {
                MenuBarPointerDriver.click(at: CGPoint(x: frame.midX, y: frame.midY))
                return
            }
            let result = AXUIElementPerformAction(entry.element, kAXPressAction as CFString)
            if result != .success {
                DispatchQueue.main.async { NSSound.beep() }
            }
        }
    }
}
