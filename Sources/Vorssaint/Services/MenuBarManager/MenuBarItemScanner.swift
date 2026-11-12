// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import ApplicationServices

/// Reads every app's menu bar icons through Accessibility. Each app exposes
/// its own icons there on every macOS version, including the ones where the
/// windows that draw them all belong to Control Center, so no window list
/// and no Screen Recording grant is involved.
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

    /// Main thread: the candidates to ask.
    static func runningApps() -> [App] {
        NSWorkspace.shared.runningApplications.compactMap { app in
            guard !app.isTerminated, app.processIdentifier > 0 else { return nil }
            let name = app.localizedName ?? app.bundleIdentifier ?? String(app.processIdentifier)
            return App(pid: app.processIdentifier, bundleID: app.bundleIdentifier, name: name)
        }
    }

    /// Off the main thread: an app that is busy holds its answer back until
    /// the timeout, and this app answers for its own icons on the main thread.
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

    private static func readEntries(for app: App) -> [Entry] {
        let application = AXUIElementCreateApplication(app.pid)
        AXUIElementSetMessagingTimeout(application, 0.4)
        var barValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, "AXExtrasMenuBar" as CFString, &barValue) == .success,
              let barValue, CFGetTypeID(barValue) == AXUIElementGetTypeID() else { return [] }
        let bar = barValue as! AXUIElement
        var childrenValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(bar, kAXChildrenAttribute as CFString, &childrenValue) == .success,
              let children = childrenValue as? [AXUIElement] else { return [] }
        var result: [Entry] = []
        for (index, child) in children.enumerated() {
            AXUIElementSetMessagingTimeout(child, 0.4)
            guard let frame = frame(of: child), frame.width > 0, frame.height > 0 else { continue }
            result.append(Entry(app: app, index: index,
                                identifier: string(child, kAXIdentifierAttribute as String),
                                title: string(child, kAXTitleAttribute as String),
                                description: string(child, kAXDescriptionAttribute as String),
                                frame: frame, element: child))
        }
        return result
    }

    static func frame(of element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue, let sizeValue,
              CFGetTypeID(positionValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue((positionValue as! AXValue), .cgPoint, &position),
              AXValueGetValue((sizeValue as! AXValue), .cgSize, &size) else { return nil }
        return CGRect(origin: position, size: size)
    }

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let text = value as? String, !text.isEmpty else { return nil }
        return text
    }
}

/// Synthetic pointer input for the two things Accessibility cannot do on a
/// menu bar icon: press one that offers no press action, and carry one to
/// another place the way a Command-drag does. Call off the main thread; both
/// pause between events so the menu bar can follow.
enum MenuBarPointerDriver {
    private static func post(_ type: CGEventType, at point: CGPoint,
                             source: CGEventSource?, flags: CGEventFlags) {
        guard let event = CGEvent(mouseEventSource: source, mouseType: type,
                                  mouseCursorPosition: point, mouseButton: .left) else { return }
        event.flags = flags
        event.post(tap: .cghidEventTap)
    }

    /// Runs `body` with the pointer cut loose from the mouse, so a hand on
    /// the mouse cannot bend the gesture, and puts the pointer back after.
    private static func withPointerHeld(_ body: (CGEventSource?) -> Void) {
        let source = CGEventSource(stateID: .hidSystemState)
        let original = CGEvent(source: nil)?.location
        CGAssociateMouseAndMouseCursorPosition(0)
        defer {
            if let original { CGWarpMouseCursorPosition(original) }
            CGAssociateMouseAndMouseCursorPosition(1)
        }
        body(source)
    }

    static func click(at point: CGPoint) {
        withPointerHeld { source in
            post(.leftMouseDown, at: point, source: source, flags: [])
            usleep(60_000)
            post(.leftMouseUp, at: point, source: source, flags: [])
            usleep(60_000)
        }
    }

    static func commandDrag(from start: CGPoint, toX endX: CGFloat) {
        withPointerHeld { source in
            let flags: CGEventFlags = .maskCommand
            post(.mouseMoved, at: start, source: source, flags: flags)
            usleep(40_000)
            post(.leftMouseDown, at: start, source: source, flags: flags)
            usleep(140_000)
            let steps = 14
            for step in 1...steps {
                let x = start.x + (endX - start.x) * CGFloat(step) / CGFloat(steps)
                post(.leftMouseDragged, at: CGPoint(x: x, y: start.y), source: source, flags: flags)
                usleep(18_000)
            }
            usleep(140_000)
            post(.leftMouseUp, at: CGPoint(x: endX, y: start.y), source: source, flags: flags)
            usleep(90_000)
        }
    }
}
