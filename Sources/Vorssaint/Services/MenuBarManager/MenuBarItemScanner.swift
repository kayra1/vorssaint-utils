// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import ApplicationServices

/// Reads menu bar icons through Accessibility. On macOS 27 every process
/// still publishes its icons under `AXExtrasMenuBar`, with frames on the
/// display whose menu bar is active; MenuBarAgent publishes the system's own,
/// each wrapped in a hosting group, next to the overflow button. A hidden
/// application publishes nothing.
enum MenuBarItemScanner {
    struct App {
        let pid: pid_t
        let bundleID: String?
        let name: String
    }

    struct Entry {
        let app: App
        /// The icon's place among its app's icons.
        let index: Int
        let identifier: String?
        let title: String?
        let description: String?
        /// Global display coordinates, origin at the top left.
        let frame: CGRect
        let element: AXUIElement
    }

    /// Main thread: the candidates to ask, MenuBarAgent first.
    static func runningApps() -> [App] {
        let apps = NSWorkspace.shared.runningApplications.compactMap { app -> App? in
            guard !app.isTerminated, app.processIdentifier > 0 else { return nil }
            let name = app.localizedName ?? app.bundleIdentifier ?? String(app.processIdentifier)
            return App(pid: app.processIdentifier, bundleID: app.bundleIdentifier, name: name)
        }
        return apps.filter { $0.bundleID == MenuBarManagerSupport.menuBarAgentBundleID }
            + apps.filter { $0.bundleID != MenuBarManagerSupport.menuBarAgentBundleID }
    }

    /// Off the main thread: a busy app holds its answer back until the
    /// timeout, and this app answers for its own icons on the main thread.
    static func scan(_ apps: [App]) -> [Entry] {
        let lock = NSLock()
        var entries: [Entry] = []
        DispatchQueue.concurrentPerform(iterations: apps.count) { position in
            let found = readEntries(for: apps[position])
            guard !found.isEmpty else { return }
            lock.lock()
            entries.append(contentsOf: found)
            lock.unlock()
        }
        return entries.sorted {
            $0.frame.minX != $1.frame.minX ? $0.frame.minX < $1.frame.minX : $0.app.pid < $1.app.pid
        }
    }

    static func readEntries(for app: App) -> [Entry] {
        let application = AXUIElementCreateApplication(app.pid)
        AXUIElementSetMessagingTimeout(application, 0.4)
        guard let bar = element(application, "AXExtrasMenuBar"),
              let children = elements(bar, kAXChildrenAttribute as String) else { return [] }
        let isAgent = app.bundleID == MenuBarManagerSupport.menuBarAgentBundleID
        var result: [Entry] = []
        for (index, child) in children.enumerated() {
            // MenuBarAgent's button child is the system overflow control.
            if isAgent, string(child, kAXRoleAttribute as String) == (kAXButtonRole as String) { continue }
            let item = isAgent ? (elements(child, kAXChildrenAttribute as String)?.first ?? child) : child
            AXUIElementSetMessagingTimeout(item, 0.4)
            guard let frame = frame(of: item), frame.width > 0, frame.height > 0 else { continue }
            result.append(Entry(app: app, index: index,
                                identifier: string(item, kAXIdentifierAttribute as String),
                                title: string(item, kAXTitleAttribute as String),
                                description: string(item, kAXDescriptionAttribute as String),
                                frame: frame, element: item))
        }
        return result
    }

    static func frame(of element: AXUIElement) -> CGRect? {
        guard let positionValue = value(element, kAXPositionAttribute as String),
              let sizeValue = value(element, kAXSizeAttribute as String),
              CFGetTypeID(positionValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue((positionValue as! AXValue), .cgPoint, &position),
              AXValueGetValue((sizeValue as! AXValue), .cgSize, &size) else { return nil }
        return CGRect(origin: position, size: size)
    }

    private static func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value
    }

    private static func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let value = value(element, attribute), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func elements(_ element: AXUIElement, _ attribute: String) -> [AXUIElement]? {
        value(element, attribute) as? [AXUIElement]
    }

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        guard let text = value(element, attribute) as? String, !text.isEmpty else { return nil }
        return text
    }
}

/// Clicks a drawn menu bar icon the way a person would, and puts the pointer
/// back. Call off the main thread.
enum MenuBarPointerDriver {
    static func click(at point: CGPoint) {
        let source = CGEventSource(stateID: .hidSystemState)
        let original = CGEvent(source: nil)?.location
        for type in [CGEventType.leftMouseDown, .leftMouseUp] {
            guard let event = CGEvent(mouseEventSource: source, mouseType: type,
                                      mouseCursorPosition: point, mouseButton: .left) else { continue }
            event.post(tap: .cghidEventTap)
            usleep(30_000)
        }
        if let original { CGWarpMouseCursorPosition(original) }
    }
}
