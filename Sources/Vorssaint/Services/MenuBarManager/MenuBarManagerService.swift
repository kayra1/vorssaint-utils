// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import ApplicationServices
import SwiftUI
import os

/// One menu bar icon as the Settings page and the categories panel show it.
struct MenuBarManagedItem: Identifiable {
    let id: String
    let bundleID: String
    let appName: String
    let title: String
    /// Set for the system's own icons, which share one generic app icon.
    let symbolName: String?
    /// Whether it was on the bar at the last look, rather than remembered.
    let isLive: Bool

    var appIcon: NSImage? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first?.icon
    }
}

/// One application with menu bar icons, which is what macOS 27 hides.
struct MenuBarManagedApp: Identifiable {
    let bundleID: String
    let name: String
    let canHide: Bool
    var id: String { bundleID }
}

/// Hides, groups and opens other apps' menu bar icons on macOS 27.
///
/// Hiding turns off the apps' "Allow in the Menu Bar" switch through
/// `MenuBarAllowList`, so it is per app: each app is visible, hidden (back
/// while the arrow is open) or always hidden (back only on Option-click).
/// The arrow is this app's own menu bar item and is never hidden. Quitting or
/// switching the feature off turns every switch it turned off back on.
/// Main thread only.
final class MenuBarManagerService: NSObject, ObservableObject {
    static let shared = MenuBarManagerService()

    @Published private(set) var isRunning = false
    @Published private(set) var revealState = MenuBarRevealState.allHidden
    @Published private(set) var applyFailed = false
    @Published private(set) var items: [MenuBarManagedItem] = []
    @Published private(set) var isScanning = false
    @Published private(set) var layout = MenuBarCategoryLayout()

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "vorssaint",
                                    category: "menubar-manager")

    private var toggleItem: NSStatusItem?
    private var shownByHover = false
    private var rehideWork: DispatchWorkItem?
    private var hoverWork: DispatchWorkItem?
    private var retryWork: DispatchWorkItem?
    private var retriesLeft = 0
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var pointerWasInBand = false
    private var runningObservation: NSKeyValueObservation?
    private var popover: NSPopover?
    /// Apps shown for a moment to open one of their icons, with a count per caller.
    private var temporarilyShown: [String: Int] = [:]
    private var remembered: [String: [MenuBarRememberedItem]] = [:]
    private var liveEntries: [String: MenuBarItemScanner.Entry] = [:]
    private let scanQueue = DispatchQueue(label: "com.vorssaint.menu-bar-manager.scan", qos: .userInitiated)

    private var defaults: UserDefaults { .standard }
    private var ownBundleID: String? { Bundle.main.bundleIdentifier }

    /// Whether this Mac can run the feature at all.
    static var isSupported: Bool { MenuBarAllowList.isAvailable }

    private override init() {
        super.init()
        remembered = MenuBarManagerSupport.decodeRemembered(
            defaults.string(forKey: DefaultsKey.menuBarManagerRememberedItems) ?? "")
    }

    // MARK: Lifecycle

    /// At launch, before any feature starts: switches a crash or a removed
    /// feature left off go back on, unless the manager is about to own them.
    static func recoverIfNeeded() {
        guard MenuBarAllowList.hasRecord else { return }
        let keeps = AppFeature.menuBarManager.isAvailable
            && UserDefaults.standard.bool(forKey: DefaultsKey.menuBarManagerEnabled)
            && isSupported
        if !keeps { MenuBarAllowList.releaseAll() }
    }

    /// On quit: every icon comes back.
    static func releaseOnQuit() {
        MenuBarAllowList.releaseAll()
    }

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
        if !isRunning {
            isRunning = true
            revealState = .allHidden
            toggleItem = makeToggleItem()
            runningObservation = NSWorkspace.shared.observe(\.runningApplications, options: [.new]) { [weak self] _, _ in
                DispatchQueue.main.async { self?.runningAppsChanged() }
            }
            // Read the bar while everything is still on it, so hidden apps
            // keep known icons, then hide.
            refreshItems { [weak self] in self?.apply() }
        } else {
            apply()
        }
        syncHoverMonitor()
        updateToggleAppearance()
    }

    private func stop() {
        guard isRunning else { return }
        isRunning = false
        cancelRehide()
        hoverWork?.cancel()
        hoverWork = nil
        retryWork?.cancel()
        retryWork = nil
        runningObservation = nil
        popover?.performClose(nil)
        popover = nil
        temporarilyShown = [:]
        if let toggleItem { NSStatusBar.system.removeStatusItem(toggleItem) }
        toggleItem = nil
        syncHoverMonitor()
        MenuBarAllowList.releaseAll()
        revealState = .allHidden
        applyFailed = false
    }

    private func runningAppsChanged() {
        guard isRunning else { return }
        apply()
    }

    // MARK: Hiding

    /// Brings the switches in line with the layout, the reveal state and any
    /// app shown for a moment.
    private func apply() {
        guard isRunning else { return }
        let concealed = MenuBarManagerSupport.concealed(
            layout: layout, state: revealState,
            temporarilyShown: Set(temporarilyShown.keys), ownBundleID: ownBundleID)
        do {
            let untracked = try MenuBarAllowList.apply(concealed: concealed)
            applyFailed = false
            // An app that never drew an icon has no switch yet. Running apps
            // are watched anyway; this covers one that draws its icon later.
            let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
            if untracked.isDisjoint(with: running) {
                retriesLeft = 0
            } else {
                scheduleRetry()
            }
        } catch {
            applyFailed = true
            Self.log.error("could not apply: \(String(describing: error), privacy: .public)")
        }
    }

    private func scheduleRetry() {
        if retriesLeft == 0 { retriesLeft = 6 }
        retriesLeft -= 1
        guard retriesLeft > 0 else { return }
        retryWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.apply() }
        retryWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }

    private func setRevealState(_ state: MenuBarRevealState) {
        guard isRunning else { return }
        if state != revealState { revealState = state }
        apply()
        updateToggleAppearance()
    }

    var isShowingHidden: Bool { revealState != .allHidden }

    func toggleHidden() {
        if isShowingHidden { hideHidden() } else { showHidden() }
    }

    func showHidden(byHover: Bool = false, includingAlwaysHidden: Bool = false) {
        guard isRunning else { return }
        cancelRehide()
        if revealState == .allHidden { shownByHover = byHover } else if !byHover { shownByHover = false }
        let target: MenuBarRevealState = includingAlwaysHidden || revealState == .allRevealed
            ? .allRevealed : .hiddenRevealed
        setRevealState(target)
        scheduleAutomaticRehide()
    }

    func hideHidden() {
        guard isRunning else { return }
        cancelRehide()
        shownByHover = false
        setRevealState(.allHidden)
    }

    private func scheduleAutomaticRehide() {
        if shownByHover {
            if !pointerIsInBand() { scheduleRehide(after: 0.8) }
            return
        }
        let seconds = MenuBarManagerSupport.sanitizedRehideSeconds(
            defaults.integer(forKey: DefaultsKey.menuBarManagerRehideSeconds))
        if seconds > 0 { scheduleRehide(after: TimeInterval(seconds)) }
    }

    private func scheduleRehide(after delay: TimeInterval) {
        rehideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.rehideIfIdle() }
        rehideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func cancelRehide() {
        rehideWork?.cancel()
        rehideWork = nil
    }

    /// Hiding under the pointer or under an open menu would pull an icon
    /// away from what the person is doing with it.
    private func rehideIfIdle() {
        guard isRunning, isShowingHidden else { return }
        if NSEvent.pressedMouseButtons != 0 || pointerIsInBand()
            || popover?.isShown == true || Self.menuIsOpen() {
            scheduleRehide(after: 1)
            return
        }
        hideHidden()
    }

    private static func menuIsOpen() -> Bool {
        let menuLevel = Int(CGWindowLevelForKey(.popUpMenuWindow))
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                       kCGNullWindowID) as? [[String: Any]] else { return false }
        return windows.contains { ($0[kCGWindowLayer as String] as? Int) == menuLevel }
    }

    // MARK: The arrow

    private func makeToggleItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = MenuBarManagerSupport.toggleAutosaveName
        item.isVisible = true
        if let button = item.button {
            button.target = self
            button.action = #selector(toggleClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        return item
    }

    private func updateToggleAppearance() {
        guard let button = toggleItem?.button else { return }
        let strings = FeatureStrings.menuBarManager(L10n.shared.language)
        let title = isShowingHidden ? strings.hideNow : strings.showNow
        let image = NSImage(systemSymbolName: isShowingHidden ? "chevron.right" : "chevron.left",
                            accessibilityDescription: title)
        image?.isTemplate = true
        button.image = image
        button.toolTip = title
    }

    @objc private func toggleClicked(_ sender: Any?) {
        let event = NSApp.currentEvent
        let secondary = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        let opensCategories = defaults.bool(forKey: DefaultsKey.menuBarManagerClickOpensCategories)
        if secondary != opensCategories {
            toggleCategoriesPanel()
        } else if event?.modifierFlags.contains(.option) == true {
            if revealState == .allRevealed { hideHidden() } else { showHidden(includingAlwaysHidden: true) }
        } else {
            toggleHidden()
        }
    }

    // MARK: Hover

    private func syncHoverMonitor() {
        let wanted = isRunning && defaults.bool(forKey: DefaultsKey.menuBarManagerShowOnHover)
        if wanted, globalMonitor == nil {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
                self?.pointerMoved()
            }
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
                self?.pointerMoved()
                return event
            }
        } else if !wanted {
            if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
            if let localMonitor { NSEvent.removeMonitor(localMonitor) }
            globalMonitor = nil
            localMonitor = nil
            pointerWasInBand = false
            hoverWork?.cancel()
            hoverWork = nil
        }
    }

    private func pointerIsInBand() -> Bool {
        let point = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) })
                ?? toggleItem?.button?.window?.screen else { return false }
        let gap = screen.frame.maxY - screen.visibleFrame.maxY
        let height = gap > 0 ? gap : NSStatusBar.system.thickness
        return MenuBarManagerSupport.isInStatusBand(point: point, screenFrame: screen.frame, barHeight: height)
    }

    private func pointerMoved() {
        let inBand = pointerIsInBand()
        guard inBand != pointerWasInBand else { return }
        pointerWasInBand = inBand
        hoverWork?.cancel()
        hoverWork = nil
        if inBand {
            guard !isShowingHidden else { return }
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.isRunning, !self.isShowingHidden, self.pointerIsInBand() else { return }
                self.showHidden(byHover: true)
            }
            hoverWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
        } else if isShowingHidden, shownByHover {
            scheduleRehide(after: 0.8)
        }
    }

    // MARK: Layout

    func updateLayout(_ change: (inout MenuBarCategoryLayout) -> Void) {
        var next = layout
        change(&next)
        next = MenuBarManagerSupport.sanitized(next)
        guard next != layout else { return }
        let sectionsChanged = next.sections != layout.sections
        layout = next
        defaults.set(MenuBarManagerSupport.encodeLayout(next), forKey: DefaultsKey.menuBarManagerCategories)
        if sectionsChanged { apply() }
    }

    func setSection(_ section: MenuBarSection, for bundleID: String) {
        guard MenuBarManagerSupport.canHide(bundleID: bundleID, ownBundleID: ownBundleID) else { return }
        updateLayout { $0.setSection(section, for: bundleID) }
    }

    /// Every app with menu bar icons, whether its icons are on the bar now or
    /// remembered from when they were.
    var apps: [MenuBarManagedApp] {
        var seen = Set<String>()
        var result: [MenuBarManagedApp] = []
        for item in items where seen.insert(item.bundleID).inserted {
            result.append(MenuBarManagedApp(
                bundleID: item.bundleID, name: item.appName,
                canHide: MenuBarManagerSupport.canHide(bundleID: item.bundleID, ownBundleID: ownBundleID)))
        }
        return result
    }

    // MARK: Listing

    /// Reads the bar again. Apps that are hidden publish nothing, so their
    /// icons come from what was seen while they showed.
    func refreshItems(then completion: (() -> Void)? = nil) {
        guard AXIsProcessTrusted() else {
            items = rememberedOnly()
            completion?()
            return
        }
        isScanning = true
        let apps = MenuBarItemScanner.runningApps()
        scanQueue.async { [weak self] in
            let entries = MenuBarItemScanner.scan(apps)
            DispatchQueue.main.async {
                guard let self else { return }
                self.absorb(entries)
                self.isScanning = false
                completion?()
            }
        }
    }

    private func rememberedOnly() -> [MenuBarManagedItem] {
        remembered.keys.sorted().flatMap { bundleID in
            (remembered[bundleID] ?? []).map { record in
                MenuBarManagedItem(id: record.key, bundleID: bundleID, appName: record.appName,
                                   title: record.title, symbolName: nil, isLive: false)
            }
        }
    }

    private func absorb(_ entries: [MenuBarItemScanner.Entry]) {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        var live: [String: MenuBarItemScanner.Entry] = [:]
        var liveItems: [MenuBarManagedItem] = []
        var seenNow: [String: [MenuBarRememberedItem]] = [:]
        for entry in entries where entry.app.pid != ownPID {
            guard let bundleID = entry.app.bundleID, !bundleID.isEmpty else { continue }
            // A frame on no display is a stale one left by Accessibility.
            guard entry.frame.width > 4, Self.isOnSomeDisplay(entry.frame) else { continue }
            let key = MenuBarManagerSupport.itemKey(bundleID: bundleID, appName: entry.app.name,
                                                    identifier: entry.identifier, index: entry.index)
            guard live[key] == nil else { continue }
            let title = MenuBarManagerSupport.displayTitle(title: entry.title, description: entry.description,
                                                           appName: entry.app.name)
            live[key] = entry
            liveItems.append(MenuBarManagedItem(
                id: key, bundleID: bundleID, appName: entry.app.name, title: title,
                symbolName: bundleID == MenuBarManagerSupport.menuBarAgentBundleID
                    ? MenuBarManagerSupport.systemSymbol(forIdentifier: entry.identifier) : nil,
                isLive: true))
            if MenuBarManagerSupport.canHide(bundleID: bundleID, ownBundleID: ownBundleID) {
                seenNow[bundleID, default: []].append(MenuBarRememberedItem(
                    key: key, title: title, appName: entry.app.name, identifier: entry.identifier))
            }
        }
        liveEntries = live
        var nextRemembered = remembered
        for (bundleID, records) in seenNow {
            nextRemembered[bundleID] = Array(records.prefix(MenuBarManagerSupport.maxRememberedPerApp))
        }
        if nextRemembered != remembered {
            remembered = nextRemembered
            defaults.set(MenuBarManagerSupport.encodeRemembered(nextRemembered),
                         forKey: DefaultsKey.menuBarManagerRememberedItems)
        }
        // Hidden apps keep their place in the list through what was remembered.
        let liveApps = Set(liveItems.map(\.bundleID))
        let hiddenApps = remembered.keys.filter { !liveApps.contains($0) && layout.section(for: $0) != .visible }
        let fromMemory = hiddenApps.sorted().flatMap { bundleID in
            (remembered[bundleID] ?? []).map { record in
                MenuBarManagedItem(id: record.key, bundleID: bundleID, appName: record.appName,
                                   title: record.title, symbolName: nil, isLive: false)
            }
        }
        items = liveItems + fromMemory
    }

    private static func isOnSomeDisplay(_ frame: CGRect) -> Bool {
        var capacity: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &capacity) == .success, capacity > 0 else { return false }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(capacity))
        var found: UInt32 = 0
        guard CGGetActiveDisplayList(capacity, &displays, &found) == .success else { return false }
        let center = CGPoint(x: frame.midX, y: frame.midY)
        return displays.prefix(Int(found)).contains { CGDisplayBounds($0).contains(center) }
    }

    // MARK: Categories panel

    private func toggleCategoriesPanel() {
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

    func closeCategoriesPanel() {
        popover?.performClose(nil)
    }

    // MARK: Opening an icon

    /// Opens an icon as a click on it would. A hidden app is shown for as
    /// long as the menu it opened stays up.
    func activate(_ item: MenuBarManagedItem) {
        closeCategoriesPanel()
        guard isRunning,
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: item.bundleID).first
        else {
            NSSound.beep()
            return
        }
        let concealed = MenuBarManagerSupport.concealed(
            layout: layout, state: revealState,
            temporarilyShown: Set(temporarilyShown.keys), ownBundleID: ownBundleID)
        let wasHidden = concealed.contains(item.bundleID) || !item.isLive
        if wasHidden {
            temporarilyShown[item.bundleID, default: 0] += 1
            apply()
        }
        let scanApp = MenuBarItemScanner.App(pid: app.processIdentifier, bundleID: item.bundleID,
                                             name: app.localizedName ?? item.appName)
        let key = item.id
        let pid = app.processIdentifier
        let fallback = liveEntries[key]?.element
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // A shown icon is drawn 0.5 to 0.6 s after its app is allowed
            // (measured by Ice on macOS 27.0); the popover needs a moment too.
            usleep(wasHidden ? 450_000 : 150_000)
            let deadline = Date().addingTimeInterval(wasHidden ? 2.5 : 0.5)
            var target: MenuBarItemScanner.Entry?
            repeat {
                let entries = MenuBarItemScanner.readEntries(for: scanApp)
                    .filter { $0.frame.width > 4 && Self.isOnSomeDisplay($0.frame) }
                target = entries.first {
                    MenuBarManagerSupport.itemKey(bundleID: scanApp.bundleID, appName: scanApp.name,
                                                  identifier: $0.identifier, index: $0.index) == key
                } ?? (key.hasSuffix("|#0") ? entries.first : nil)
                if target == nil { usleep(120_000) }
            } while target == nil && Date() < deadline
            let baseline = Self.windowNumbers(ownedBy: pid)
            var opened = false
            if let target {
                MenuBarPointerDriver.click(at: CGPoint(x: target.frame.midX, y: target.frame.midY))
                opened = true
            } else if let fallback {
                // Not drawn anywhere, folded behind the system's overflow
                // control for example: Accessibility can still press it.
                let result = AXUIElementPerformAction(fallback, kAXPressAction as CFString)
                opened = result == .success
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
        apply()
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
