// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import ApplicationServices
import SwiftUI

/// One menu bar icon as the layout editor and the categories panel show it.
struct MenuBarManagedItem: Identifiable {
    let id: String
    let pid: pid_t
    let appName: String
    let title: String
    /// Set for the system's own icons, which share one generic app icon.
    let symbolName: String?
    /// Global display coordinates, origin at the top left.
    let frame: CGRect
    let section: MenuBarSection
    let element: AXUIElement

    var appIcon: NSImage? { NSRunningApplication(processIdentifier: pid)?.icon }
}

/// Where the layout editor asks an icon to go.
enum MenuBarMoveTarget: Equatable {
    case section(MenuBarSection)
    /// Immediately to the left of another icon.
    case before(itemID: String)
}

/// Hides, groups and rearranges the menu bar's icons.
///
/// Hiding uses two status items of its own: an arrow, and a divider that can
/// stretch far wider than the screen. Stretched, the divider pushes every
/// icon on its left off the screen; shrunk, they come back. An optional
/// second divider further left does the same for icons that stay away even
/// while the first section shows. Nothing is done to the other apps: quitting
/// or switching the feature off removes the dividers and every icon returns.
///
/// Listing, pressing and moving other apps' icons goes through Accessibility
/// and only happens when the editor or the categories panel asks for it.
/// Main thread only.
final class MenuBarManagerService: NSObject, ObservableObject {
    static let shared = MenuBarManagerService()

    @Published private(set) var isRunning = false
    /// True while the hidden section is on screen.
    @Published private(set) var isShowingHidden = true
    /// The divider sits right of the arrow, so stretching it would take the
    /// arrow away too and nothing can be hidden.
    @Published private(set) var dividerMisplaced = false
    @Published private(set) var items: [MenuBarManagedItem] = []
    @Published private(set) var isScanning = false
    @Published private(set) var isMoving = false
    @Published private(set) var moveFailed = false
    @Published private(set) var layout = MenuBarCategoryLayout()

    private enum RehideMode {
        case everything, alwaysHiddenOnly
    }

    private enum ControlPlacement {
        case unknown, valid, misplaced
    }

    private var toggleItem: NSStatusItem?
    private var dividerItem: NSStatusItem?
    private var alwaysHiddenItem: NSStatusItem?
    private var alwaysHiddenRevealed = false
    private var shownByHover = false
    private var temporaryReveal = false
    private var temporaryHold: TimeInterval = 6
    private var rehideWork: DispatchWorkItem?
    private var rehideMode = RehideMode.everything
    private var hoverWork: DispatchWorkItem?
    private var hideRetriesLeft = 0
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var pointerWasInBand = false
    private var popover: NSPopover?
    private let scanQueue = DispatchQueue(label: "com.vorssaint.menu-bar-manager.scan", qos: .userInitiated)

    private var defaults: UserDefaults { .standard }

    private override init() {
        super.init()
    }

    // MARK: Lifecycle

    func syncWithPreferences() {
        let stored = MenuBarManagerSupport.decodeLayout(
            defaults.string(forKey: DefaultsKey.menuBarManagerCategories) ?? "")
        if stored != layout { layout = stored }
        guard AppFeature.menuBarManager.isAvailable,
              defaults.bool(forKey: DefaultsKey.menuBarManagerEnabled) else {
            stop()
            return
        }
        start()
    }

    private func start() {
        let firstStart = !isRunning
        // Created right to left: each new status item lands on the far left,
        // which leaves the divider left of the arrow with nothing hidden yet.
        if toggleItem == nil { toggleItem = makeToggleItem() }
        if dividerItem == nil {
            dividerItem = makeDivider(autosaveName: MenuBarManagerSupport.dividerAutosaveName, dimmed: false)
        }
        let wantsAlwaysHidden = defaults.bool(forKey: DefaultsKey.menuBarManagerAlwaysHidden)
        if wantsAlwaysHidden, alwaysHiddenItem == nil {
            alwaysHiddenItem = makeDivider(autosaveName: MenuBarManagerSupport.alwaysHiddenAutosaveName,
                                           dimmed: true)
        } else if !wantsAlwaysHidden, let item = alwaysHiddenItem {
            NSStatusBar.system.removeStatusItem(item)
            alwaysHiddenItem = nil
            alwaysHiddenRevealed = false
        }
        isRunning = true
        MenuBarManagerState.reveal = { [weak self] in
            // Long enough for the icon recovery to look for it several times.
            self?.showHidden(temporarily: true, revealAlwaysHidden: true, holdingFor: 45)
        }
        syncHoverMonitor()
        applyLengths()
        guard firstStart else { return }
        // macOS restores the saved positions a moment after the items exist,
        // and only settled frames say whether hiding is safe.
        hideRetriesLeft = 10
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self, self.isRunning, self.isShowingHidden, !self.isMoving else { return }
            self.hideHidden()
        }
    }

    private func stop() {
        guard isRunning || toggleItem != nil else { return }
        cancelRehide()
        hoverWork?.cancel()
        hoverWork = nil
        popover?.performClose(nil)
        popover = nil
        for item in [toggleItem, dividerItem, alwaysHiddenItem].compactMap({ $0 }) {
            NSStatusBar.system.removeStatusItem(item)
        }
        toggleItem = nil
        dividerItem = nil
        alwaysHiddenItem = nil
        isRunning = false
        isShowingHidden = true
        dividerMisplaced = false
        alwaysHiddenRevealed = false
        shownByHover = false
        temporaryReveal = false
        MenuBarManagerState.isHidingItems = false
        MenuBarManagerState.reveal = nil
        syncHoverMonitor()
    }

    /// Forgets where the arrow and the dividers were and puts them back at
    /// the far left in working order. Every icon ends up visible.
    func resetPositions() {
        guard isRunning else { return }
        stop()
        for name in MenuBarManagerSupport.controlAutosaveNames {
            defaults.removeObject(forKey: StatusItemPlacementSupport.preferredPositionKey(for: name))
        }
        syncWithPreferences()
    }

    // MARK: Status items

    private func makeToggleItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = MenuBarManagerSupport.toggleAutosaveName
        item.isVisible = true
        if let button = item.button {
            button.target = self
            button.action = #selector(toggleClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.setAccessibilityIdentifier(MenuBarManagerSupport.toggleAutosaveName)
        }
        return item
    }

    private func makeDivider(autosaveName: String, dimmed: Bool) -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = autosaveName
        item.isVisible = true
        if let button = item.button {
            button.image = Self.dividerImage
            button.appearsDisabled = dimmed
            button.setAccessibilityIdentifier(autosaveName)
            // A stretched divider covers the bar's empty space; a click there
            // must not light it up.
            (button.cell as? NSButtonCell)?.highlightsBy = []
        }
        return item
    }

    private static let dividerImage: NSImage = {
        let image = NSImage(size: NSSize(width: 7, height: 16), flipped: false) { _ in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: NSRect(x: 2.75, y: 3, width: 1.5, height: 10),
                         xRadius: 0.75, yRadius: 0.75).fill()
            return true
        }
        image.isTemplate = true
        return image
    }()

    private func frame(of item: NSStatusItem?) -> CGRect? {
        guard let frame = item?.button?.window?.frame, frame.width > 0 else { return nil }
        return frame
    }

    private func controlPlacement() -> ControlPlacement {
        guard let toggle = frame(of: toggleItem), let divider = frame(of: dividerItem),
              StatusItemPlacementSupport.isPlacedStatusFrame(
                toggle, screenFrames: NSScreen.screens.map(\.frame)) else { return .unknown }
        return MenuBarManagerSupport.dividerIsLeftOfToggle(toggleMinX: toggle.minX, dividerMaxX: divider.maxX)
            ? .valid : .misplaced
    }

    /// The second divider only takes part from the left of the first.
    private var alwaysHiddenUsable: Bool {
        guard let always = frame(of: alwaysHiddenItem), let divider = frame(of: dividerItem) else { return false }
        return MenuBarManagerSupport.alwaysHiddenIsLeftOfDivider(alwaysHiddenMaxX: always.maxX,
                                                                 dividerMinX: divider.minX)
    }

    private func applyLengths() {
        let standard = NSStatusItem.variableLength
        let stretched = MenuBarManagerSupport.expandedLength
        var holdsAlwaysHidden = false
        if isShowingHidden {
            // The second divider stretches before the first lets go, so its
            // icons never flash by on the way.
            if let always = alwaysHiddenItem {
                holdsAlwaysHidden = alwaysHiddenUsable && !alwaysHiddenRevealed
                always.length = holdsAlwaysHidden ? stretched : standard
                always.button?.image = holdsAlwaysHidden ? nil : Self.dividerImage
            }
            dividerItem?.length = standard
            dividerItem?.button?.image = Self.dividerImage
        } else {
            dividerItem?.length = stretched
            dividerItem?.button?.image = nil
            alwaysHiddenItem?.length = standard
            alwaysHiddenItem?.button?.image = Self.dividerImage
        }
        MenuBarManagerState.isHidingItems = isRunning && (!isShowingHidden || holdsAlwaysHidden)
        updateToggleAppearance()
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
        dividerItem?.button?.toolTip = strings.dividerTooltip
        alwaysHiddenItem?.button?.toolTip = strings.alwaysHiddenLabel
    }

    // MARK: Showing and hiding

    @objc private func toggleClicked(_ sender: Any?) {
        let event = NSApp.currentEvent
        let secondary = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        let opensCategories = defaults.bool(forKey: DefaultsKey.menuBarManagerClickOpensCategories)
        if secondary != opensCategories {
            toggleCategoriesPanel()
        } else if event?.modifierFlags.contains(.option) == true {
            showHidden(revealAlwaysHidden: true)
        } else {
            toggleHidden()
        }
    }

    func toggleHidden() {
        if isShowingHidden {
            hideHidden()
            if dividerMisplaced { NSSound.beep() }
        } else {
            showHidden()
        }
    }

    func showHidden(byHover: Bool = false, temporarily: Bool = false, revealAlwaysHidden: Bool = false,
                    holdingFor hold: TimeInterval = 6) {
        guard isRunning else { return }
        cancelRehide()
        temporaryHold = hold
        if revealAlwaysHidden, alwaysHiddenItem != nil { alwaysHiddenRevealed = true }
        if !isShowingHidden {
            shownByHover = byHover
            temporaryReveal = temporarily
            isShowingHidden = true
        } else if !byHover, !temporarily {
            // An explicit request keeps open what a hover or a press opened.
            shownByHover = false
            temporaryReveal = false
        }
        applyLengths()
        scheduleAutomaticRehide()
    }

    func hideHidden() {
        guard isRunning else { return }
        cancelRehide()
        switch controlPlacement() {
        case .unknown:
            // No settled frame yet; ask again rather than hide blind.
            guard hideRetriesLeft > 0 else { return }
            hideRetriesLeft -= 1
            scheduleRehide(after: 1, mode: .everything)
            return
        case .misplaced:
            dividerMisplaced = true
            if !isShowingHidden { isShowingHidden = true }
            applyLengths()
            return
        case .valid:
            dividerMisplaced = false
            hideRetriesLeft = 10
        }
        alwaysHiddenRevealed = false
        shownByHover = false
        temporaryReveal = false
        isShowingHidden = false
        applyLengths()
    }

    private func scheduleAutomaticRehide() {
        let seconds = MenuBarManagerSupport.sanitizedRehideSeconds(
            defaults.integer(forKey: DefaultsKey.menuBarManagerRehideSeconds))
        if temporaryReveal {
            scheduleRehide(after: temporaryHold, mode: .everything)
        } else if shownByHover {
            if !pointerIsInBand() { scheduleRehide(after: 0.8, mode: .everything) }
        } else if seconds > 0 {
            scheduleRehide(after: TimeInterval(seconds), mode: .everything)
        } else if alwaysHiddenRevealed {
            scheduleRehide(after: temporaryHold, mode: .alwaysHiddenOnly)
        }
    }

    private func scheduleRehide(after delay: TimeInterval, mode: RehideMode) {
        rehideWork?.cancel()
        rehideMode = mode
        let work = DispatchWorkItem { [weak self] in self?.rehideIfIdle() }
        rehideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func cancelRehide() {
        rehideWork?.cancel()
        rehideWork = nil
    }

    /// Hiding under the pointer, under an open menu or in the middle of a
    /// drag would pull an icon away from what the person is doing with it.
    private func rehideIfIdle() {
        guard isRunning, !isMoving else { return }
        if NSEvent.pressedMouseButtons != 0 || pointerIsInBand()
            || popover?.isShown == true || Self.menuIsOpen() {
            scheduleRehide(after: 1, mode: rehideMode)
            return
        }
        switch rehideMode {
        case .everything:
            hideHidden()
        case .alwaysHiddenOnly:
            alwaysHiddenRevealed = false
            applyLengths()
        }
    }

    private static func menuIsOpen() -> Bool {
        let menuLevel = Int(CGWindowLevelForKey(.popUpMenuWindow))
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                       kCGNullWindowID) as? [[String: Any]] else { return false }
        return windows.contains { ($0[kCGWindowLayer as String] as? Int) == menuLevel }
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
        }
    }

    private func pointerIsInBand() -> Bool {
        guard let screen = toggleItem?.button?.window?.screen ?? NSScreen.screens.first else { return false }
        let gap = screen.frame.maxY - screen.visibleFrame.maxY
        let height = gap > 0 ? gap : NSStatusBar.system.thickness
        return MenuBarManagerSupport.isInStatusBand(point: NSEvent.mouseLocation,
                                                    screenFrame: screen.frame, barHeight: height)
    }

    private func pointerMoved() {
        let inBand = pointerIsInBand()
        guard inBand != pointerWasInBand else { return }
        pointerWasInBand = inBand
        hoverWork?.cancel()
        hoverWork = nil
        if inBand {
            guard !isShowingHidden, !isMoving else { return }
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.isRunning, !self.isShowingHidden, !self.isMoving,
                      self.pointerIsInBand() else { return }
                self.showHidden(byHover: true)
            }
            hoverWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
        } else if isShowingHidden, shownByHover {
            scheduleRehide(after: 0.8, mode: .everything)
        }
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

    /// Opens an icon as a click on it would, bringing it on screen first.
    func activate(_ item: MenuBarManagedItem) {
        closeCategoriesPanel()
        let offScreen: Bool
        switch item.section {
        case .visible: offScreen = false
        case .hidden: offScreen = !isShowingHidden
        case .alwaysHidden: offScreen = !isShowingHidden || !alwaysHiddenRevealed
        }
        if offScreen {
            showHidden(temporarily: true, revealAlwaysHidden: item.section == .alwaysHidden)
        }
        // The bar needs a moment to bring the icon back, and the panel to close.
        let element = item.element
        DispatchQueue.main.asyncAfter(deadline: .now() + (offScreen ? 0.4 : 0.15)) {
            DispatchQueue.global(qos: .userInitiated).async {
                AXUIElementSetMessagingTimeout(element, 0.6)
                let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
                // An app tracking the menu it just opened does not answer in
                // time, so only an icon that cannot be pressed gets a click.
                guard result == .actionUnsupported || result == .notImplemented,
                      let frame = MenuBarItemScanner.frame(of: element) else { return }
                MenuBarPointerDriver.click(at: CGPoint(x: frame.midX, y: frame.midY))
            }
        }
    }

    // MARK: Listing

    /// Reads the menu bar's icons again. Without Accessibility the list is
    /// empty and the editor asks for the grant instead.
    func refreshItems(then completion: (() -> Void)? = nil) {
        guard AXIsProcessTrusted() else {
            items = []
            completion?()
            return
        }
        isScanning = true
        let apps = MenuBarItemScanner.runningApps()
        scanQueue.async { [weak self] in
            let entries = MenuBarItemScanner.scan(apps)
            DispatchQueue.main.async {
                guard let self else { return }
                self.items = self.makeItems(from: entries)
                self.isScanning = false
                completion?()
            }
        }
    }

    private func makeItems(from entries: [MenuBarItemScanner.Entry]) -> [MenuBarManagedItem] {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let controlFrames = [toggleItem, dividerItem, alwaysHiddenItem].compactMap { frame(of: $0) }
        let dividerMinX = frame(of: dividerItem)?.minX
        let alwaysHiddenMinX = alwaysHiddenUsable ? frame(of: alwaysHiddenItem)?.minX : nil
        return entries.compactMap { entry -> MenuBarManagedItem? in
            if entry.app.pid == ownPID {
                // The arrow and the dividers are the manager, not its subject.
                if let identifier = entry.identifier,
                   MenuBarManagerSupport.controlAutosaveNames.contains(identifier) { return nil }
                if controlFrames.contains(where: {
                    abs($0.minX - entry.frame.minX) < 2 && abs($0.width - entry.frame.width) < 2
                }) { return nil }
            }
            return MenuBarManagedItem(
                id: MenuBarManagerSupport.itemKey(bundleID: entry.app.bundleID, appName: entry.app.name,
                                                  identifier: entry.identifier, index: entry.index),
                pid: entry.app.pid,
                appName: entry.app.name,
                title: MenuBarManagerSupport.displayTitle(title: entry.title, description: entry.description,
                                                          appName: entry.app.name),
                symbolName: MenuBarManagerSupport.systemSymbol(forIdentifier: entry.identifier),
                frame: entry.frame,
                section: MenuBarManagerSupport.section(midX: entry.frame.midX, dividerMinX: dividerMinX,
                                                       alwaysHiddenMinX: alwaysHiddenMinX),
                element: entry.element)
        }
    }

    // MARK: Moving

    /// Carries an icon to another section or beside another icon with the
    /// same Command-drag a person would make. Every section is brought on
    /// screen for the drag and put back afterwards.
    func move(itemID: String, to target: MenuBarMoveTarget) {
        guard isRunning, !isMoving, AXIsProcessTrusted() else { return }
        isMoving = true
        moveFailed = false
        let wasShowing = isShowingHidden
        let hadAlwaysHiddenRevealed = alwaysHiddenRevealed
        cancelRehide()
        alwaysHiddenRevealed = true
        isShowingHidden = true
        applyLengths()
        let finish: (Bool) -> Void = { [weak self] succeeded in
            guard let self else { return }
            self.moveFailed = !succeeded
            self.isMoving = false
            guard self.isRunning else { return }
            if wasShowing {
                self.alwaysHiddenRevealed = hadAlwaysHiddenRevealed
                self.applyLengths()
                self.scheduleAutomaticRehide()
            } else {
                self.hideHidden()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self else { return }
            self.refreshItems { [weak self] in
                guard let self else { return }
                self.performMove(itemID: itemID, target: target, finish: finish)
            }
        }
    }

    private func performMove(itemID: String, target: MenuBarMoveTarget, finish: @escaping (Bool) -> Void) {
        guard isRunning, let item = items.first(where: { $0.id == itemID }),
              let divider = frame(of: dividerItem) else {
            finish(false)
            return
        }
        let plan: MenuBarManagerSupport.MovePlan
        switch target {
        case .section(let section):
            if item.section == section {
                finish(true)
                return
            }
            let always = alwaysHiddenUsable ? frame(of: alwaysHiddenItem) : nil
            guard let sectionPlan = MenuBarManagerSupport.sectionMove(
                from: item.section, to: section, divider: divider, alwaysHidden: always) else {
                finish(false)
                return
            }
            plan = sectionPlan
        case .before(let otherID):
            guard otherID != itemID, let other = items.first(where: { $0.id == otherID }) else {
                finish(false)
                return
            }
            plan = MenuBarManagerSupport.MovePlan(anchor: other.frame, placement: .before)
        }
        let dropX = MenuBarManagerSupport.dropCenterX(moving: item.frame, plan: plan)
        let start = CGPoint(x: item.frame.midX, y: item.frame.midY)
        // Both ends of the drag have to be somewhere a pointer can reach.
        let reachable = NSScreen.screens.contains { screen in
            screen.frame.minX <= min(start.x, dropX) && max(start.x, dropX) <= screen.frame.maxX
        }
        guard reachable else {
            finish(false)
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            MenuBarPointerDriver.commandDrag(from: start, toX: dropX)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self else { return }
                self.refreshItems { [weak self] in
                    guard let self else { return }
                    finish(self.moveSucceeded(itemID: itemID, target: target))
                }
            }
        }
    }

    private func moveSucceeded(itemID: String, target: MenuBarMoveTarget) -> Bool {
        guard let item = items.first(where: { $0.id == itemID }) else { return false }
        switch target {
        case .section(let section):
            return item.section == section
        case .before(let otherID):
            guard let other = items.first(where: { $0.id == otherID }) else { return false }
            return item.frame.midX < other.frame.midX && item.section == other.section
        }
    }
}

/// The system-wide gap between menu bar icons. These are macOS's own hidden
/// preferences, read by each app as it launches, so a change reaches an app
/// the next time it opens.
enum MenuBarItemSpacingPreference {
    static func value(forKey key: String) -> Int? {
        let value = CFPreferencesCopyValue(key as CFString, kCFPreferencesAnyApplication,
                                           kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        return (value as? NSNumber)?.intValue
    }

    /// nil removes the preference and returns the spacing to macOS.
    static func setValue(_ value: Int?, forKey key: String) {
        let number: CFPropertyList? = MenuBarManagerSupport.sanitizedSpacing(value).map { NSNumber(value: $0) }
        CFPreferencesSetValue(key as CFString, number, kCFPreferencesAnyApplication,
                              kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser,
                                 kCFPreferencesCurrentHost)
    }
}
