// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import ApplicationServices
import SwiftUI
import os

/// One menu bar icon as the Settings page and the dropdown show it.
struct MenuBarManagedItem: Identifiable {
    let id: String
    let bundleID: String
    let appName: String
    let title: String
    /// Set for the system's own icons, which share one generic app icon.
    let symbolName: String?
    /// Whether it was on the bar at the last look, rather than remembered
    /// from before its app was hidden.
    let isLive: Bool

    var appIcon: NSImage? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first?.icon
    }
}

/// A dropdown of every menu bar icon, grouped into the person's categories,
/// behind one arrow in the menu bar, the way Windows gathers its tray icons.
/// Clicking an icon in the dropdown clicks the real one. Icons are read and
/// opened through Accessibility.
///
/// Apps can also be kept out of the menu bar. That turns off their "Allow in
/// the Menu Bar" switch through `MenuBarAllowList`, so it is per app. Their
/// icons stay in the dropdown from when they were last seen, and opening one
/// shows the app only while its menu is up. Switching the feature off or
/// quitting turns back on every switch it turned off. Main thread only.
final class MenuBarManagerService: NSObject, ObservableObject {
    static let shared = MenuBarManagerService()

    @Published private(set) var isRunning = false
    @Published private(set) var items: [MenuBarManagedItem] = []
    @Published private(set) var isScanning = false
    @Published private(set) var layout = MenuBarCategoryLayout()
    @Published private(set) var hideFailed = false

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "vorssaint",
                                    category: "menubar-manager")

    private var toggleItem: NSStatusItem?
    private var popover: NSPopover?
    private var entries: [String: MenuBarItemScanner.Entry] = [:]
    private var remembered: [String: [MenuBarRememberedItem]] = [:]
    /// Apps shown for a moment to open one of their icons, with a count per caller.
    private var temporarilyShown: [String: Int] = [:]
    private var runningObservation: NSKeyValueObservation?
    private var retryWork: DispatchWorkItem?
    private var retriesLeft = 0
    private let scanQueue = DispatchQueue(label: "com.vorssaint.menu-bar-manager.scan", qos: .userInitiated)

    private var defaults: UserDefaults { .standard }
    private var ownBundleID: String? { Bundle.main.bundleIdentifier }

    /// The feature is offered on macOS 27 and later only.
    static var isSupported: Bool {
        if #available(macOS 27, *) { return true }
        return false
    }

    /// Whether apps can be hidden: macOS 27 with the calls the switch needs.
    static var canHideApps: Bool { MenuBarAllowList.isAvailable }

    private override init() {
        super.init()
        remembered = MenuBarManagerSupport.decodeRemembered(
            defaults.string(forKey: DefaultsKey.menuBarManagerRememberedItems) ?? "")
    }

    /// At launch, before any feature starts: switches a crash or a removed
    /// feature left off go back on, unless the dropdown is about to own them.
    static func recoverIfNeeded() {
        guard MenuBarAllowList.hasRecord else { return }
        let keeps = AppFeature.menuBarManager.isAvailable
            && UserDefaults.standard.bool(forKey: DefaultsKey.menuBarManagerEnabled)
            && isSupported && canHideApps
        if !keeps { MenuBarAllowList.releaseAll() }
    }

    /// On quit: every hidden app comes back.
    static func releaseOnQuit() {
        MenuBarAllowList.releaseAll()
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
        runningObservation = NSWorkspace.shared.observe(\.runningApplications, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.applyHiding() }
        }
        // Read the bar while everything is still on it, so hidden apps keep
        // known icons, then hide.
        refreshItems { [weak self] in self?.applyHiding() }
    }

    private func stop() {
        guard isRunning else { return }
        isRunning = false
        popover?.performClose(nil)
        popover = nil
        if let toggleItem { NSStatusBar.system.removeStatusItem(toggleItem) }
        toggleItem = nil
        runningObservation = nil
        retryWork?.cancel()
        retryWork = nil
        temporarilyShown = [:]
        MenuBarAllowList.releaseAll()
        hideFailed = false
    }

    // MARK: Hiding

    /// Brings the switches in line with the hidden apps and any app shown
    /// for a moment.
    private func applyHiding() {
        guard isRunning, Self.canHideApps else { return }
        let concealed = MenuBarManagerSupport.concealed(
            layout: layout, temporarilyShown: Set(temporarilyShown.keys), ownBundleID: ownBundleID)
        guard !concealed.isEmpty || MenuBarAllowList.hasRecord else {
            hideFailed = false
            return
        }
        do {
            let untracked = try MenuBarAllowList.apply(concealed: concealed)
            hideFailed = false
            // An app that never drew an icon has no switch yet; try again a
            // little later in case it draws one.
            let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
            if untracked.isDisjoint(with: running) {
                retriesLeft = 0
            } else {
                scheduleRetry()
            }
        } catch {
            hideFailed = true
            Self.log.error("could not hide: \(String(describing: error), privacy: .public)")
        }
    }

    private func scheduleRetry() {
        if retriesLeft == 0 { retriesLeft = 6 }
        retriesLeft -= 1
        guard retriesLeft > 0 else { return }
        retryWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.applyHiding() }
        retryWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }

    func setHidden(_ hidden: Bool, for bundleID: String) {
        guard MenuBarManagerSupport.canHide(bundleID: bundleID, ownBundleID: ownBundleID) else { return }
        updateLayout { $0.setHidden(hidden, for: bundleID) }
    }

    /// Every app with menu bar icons, on the bar now or hidden, in bar order,
    /// then hidden apps that are not running, so each can always be shown again.
    var apps: [MenuBarManagedApp] {
        var seen = Set<String>()
        var result: [MenuBarManagedApp] = []
        for item in items where seen.insert(item.bundleID).inserted {
            result.append(MenuBarManagedApp(
                bundleID: item.bundleID, name: item.appName,
                canHide: MenuBarManagerSupport.canHide(bundleID: item.bundleID, ownBundleID: ownBundleID)))
        }
        for bundleID in layout.hiddenApps.sorted() where seen.insert(bundleID).inserted {
            let name = remembered[bundleID]?.first?.appName ?? bundleID
            result.append(MenuBarManagedApp(bundleID: bundleID, name: name, canHide: true))
        }
        return result
    }

    // MARK: Categories

    func updateLayout(_ change: (inout MenuBarCategoryLayout) -> Void) {
        var next = layout
        change(&next)
        next = MenuBarManagerSupport.sanitized(next)
        guard next != layout else { return }
        let hidingChanged = next.hiddenApps != layout.hiddenApps
        layout = next
        defaults.set(MenuBarManagerSupport.encodeLayout(next), forKey: DefaultsKey.menuBarManagerCategories)
        if hidingChanged {
            applyHiding()
            // macOS fades an app out or back in over about a quarter second.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                guard let self, self.isRunning else { return }
                self.refreshItems()
            }
        }
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

    /// Reads every app's menu bar icons again. Hidden apps publish nothing,
    /// so their icons come from what was seen while they showed.
    func refreshItems(then completion: (() -> Void)? = nil) {
        guard AXIsProcessTrusted() else {
            items = []
            entries = [:]
            completion?()
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
                completion?()
            }
        }
    }

    private func absorb(_ found: [MenuBarItemScanner.Entry]) {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        var nextEntries: [String: MenuBarItemScanner.Entry] = [:]
        var nextItems: [MenuBarManagedItem] = []
        var seenNow: [String: [MenuBarRememberedItem]] = [:]
        for entry in found where entry.app.pid != ownPID {
            guard let bundleID = entry.app.bundleID, !bundleID.isEmpty,
                  entry.frame.width > 4, Self.isOnSomeDisplay(entry.frame) else { continue }
            let key = MenuBarManagerSupport.itemKey(bundleID: bundleID, appName: entry.app.name,
                                                    identifier: entry.identifier, index: entry.index)
            guard nextEntries[key] == nil else { continue }
            let title = MenuBarManagerSupport.displayTitle(title: entry.title, description: entry.description,
                                                           appName: entry.app.name)
            nextEntries[key] = entry
            nextItems.append(MenuBarManagedItem(
                id: key, bundleID: bundleID, appName: entry.app.name, title: title,
                symbolName: bundleID == MenuBarManagerSupport.menuBarAgentBundleID
                    ? MenuBarManagerSupport.systemSymbol(forIdentifier: entry.identifier) : nil,
                isLive: true))
            if MenuBarManagerSupport.canHide(bundleID: bundleID, ownBundleID: ownBundleID) {
                seenNow[bundleID, default: []].append(MenuBarRememberedItem(
                    key: key, title: title, appName: entry.app.name, identifier: entry.identifier))
            }
        }
        entries = nextEntries
        var nextRemembered = remembered
        for (bundleID, records) in seenNow {
            nextRemembered[bundleID] = Array(records.prefix(MenuBarManagerSupport.maxRememberedPerApp))
        }
        if nextRemembered != remembered {
            remembered = nextRemembered
            defaults.set(MenuBarManagerSupport.encodeRemembered(nextRemembered),
                         forKey: DefaultsKey.menuBarManagerRememberedItems)
        }
        // A hidden app that is running keeps its place through what was seen
        // of it before.
        let liveApps = Set(nextItems.map(\.bundleID))
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let hiddenRunning = layout.hiddenApps.filter { !liveApps.contains($0) && running.contains($0) }.sorted()
        let fromMemory = hiddenRunning.flatMap { bundleID -> [MenuBarManagedItem] in
            let records = remembered[bundleID] ?? []
            guard !records.isEmpty else {
                // Never seen while showing: one entry named after the app.
                let name = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                    .first?.localizedName ?? bundleID
                return [MenuBarManagedItem(id: bundleID + "|#0", bundleID: bundleID, appName: name,
                                           title: name, symbolName: nil, isLive: false)]
            }
            return records.map { record in
                MenuBarManagedItem(id: record.key, bundleID: bundleID, appName: record.appName,
                                   title: record.title, symbolName: nil, isLive: false)
            }
        }
        items = nextItems + fromMemory
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
    /// system folded behind its overflow control. A hidden app is shown for
    /// as long as the menu it opened stays up.
    func activate(_ item: MenuBarManagedItem) {
        closeDropdown()
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: item.bundleID).first else {
            NSSound.beep()
            return
        }
        let wasHidden = layout.isHidden(item.bundleID) && Self.canHideApps
            && MenuBarManagerSupport.canHide(bundleID: item.bundleID, ownBundleID: ownBundleID)
        if wasHidden {
            temporarilyShown[item.bundleID, default: 0] += 1
            applyHiding()
        }
        let scanApp = MenuBarItemScanner.App(pid: app.processIdentifier, bundleID: item.bundleID,
                                             name: app.localizedName ?? item.appName)
        let key = item.id
        let pid = app.processIdentifier
        let fallback = entries[key]?.element
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // A shown icon is drawn about half a second after its app is
            // allowed again (measured by Ice on macOS 27.0); the dropdown
            // needs a moment to close either way.
            usleep(wasHidden ? 450_000 : 150_000)
            let deadline = Date().addingTimeInterval(wasHidden ? 2.5 : 0.4)
            var target: MenuBarItemScanner.Entry?
            repeat {
                let drawn = MenuBarItemScanner.readEntries(for: scanApp)
                    .filter { $0.frame.width > 4 && Self.isOnSomeDisplay($0.frame) }
                target = drawn.first {
                    MenuBarManagerSupport.itemKey(bundleID: scanApp.bundleID, appName: scanApp.name,
                                                  identifier: $0.identifier, index: $0.index) == key
                } ?? (key.hasSuffix("|#0") ? drawn.first : nil)
                if target == nil { usleep(120_000) }
            } while target == nil && Date() < deadline
            let baseline = Self.windowNumbers(ownedBy: pid)
            var opened = false
            if let target {
                MenuBarPointerDriver.click(at: CGPoint(x: target.frame.midX, y: target.frame.midY))
                opened = true
            } else if let fallback {
                opened = AXUIElementPerformAction(fallback, kAXPressAction as CFString) == .success
            }
            if opened, wasHidden {
                // Keep the app shown while the menu or panel it opened is up.
                usleep(400_000)
                var waited = 0
                while waited < 240, !Self.windowNumbers(ownedBy: pid).subtracting(baseline).isEmpty {
                    usleep(250_000)
                    waited += 1
                }
            }
            DispatchQueue.main.async {
                guard let self else { return }
                if !opened { NSSound.beep() }
                if wasHidden { self.endTemporaryShow(item.bundleID) }
            }
        }
    }

    private func endTemporaryShow(_ bundleID: String) {
        guard let count = temporarilyShown[bundleID] else { return }
        temporarilyShown[bundleID] = count > 1 ? count - 1 : nil
        applyHiding()
    }

    private static func windowNumbers(ownedBy pid: pid_t) -> Set<Int> {
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                 kCGNullWindowID) as? [[String: Any]] ?? []
        return Set(windows.compactMap { window in
            guard (window[kCGWindowOwnerPID as String] as? Int32) == pid else { return nil }
            return window[kCGWindowNumber as String] as? Int
        })
    }
}

/// One app with menu bar icons, which is what macOS 27 hides.
struct MenuBarManagedApp: Identifiable {
    let bundleID: String
    let name: String
    let canHide: Bool
    var id: String { bundleID }
}
