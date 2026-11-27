// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Foundation
import os

/// Hides applications' menu bar icons by turning off their "Allow in the Menu
/// Bar" switch, the one macOS 27 keeps per application in System Settings.
///
/// Measured by Ice on macOS 27.0.1 (https://github.com/jordanbaird/Ice,
/// GPL-3.0): writing `isAllowed = false` fades an application's icons out
/// within about 250 ms and gives their room back, and `true` brings them
/// back, with no restart. Clicks on the clock, Control Center and the camera
/// indicator are untouched. The write must go through CoreFoundation's
/// container-aware preference calls: a plain file write changes nothing until
/// MenuBarAgent restarts.
///
/// The switch belongs to the person as much as to this app, so every switch
/// this app turns off is recorded, and only those are ever turned back on.
/// The record outlives a crash: whatever is in it is turned back on at the
/// next launch. Main thread only.
enum MenuBarAllowList {
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "vorssaint",
                                    category: "menubar-manager")

    enum Failure: Error {
        case unavailable, unreadable, notSynchronized
    }

    /// macOS 27 or later, with the private calls present. Whether the list
    /// can be read is answered by each `apply`, which the Settings page
    /// reports, so a passing read failure never reads as the wrong macOS.
    static let isAvailable: Bool = {
        guard #available(macOS 27, *) else { return false }
        return Preferences.shared != nil
    }()

    /// What this app has turned off and not yet back on. Kept in memory as
    /// well, so quitting can still restore it after the preferences file was
    /// removed (as uninstalling does).
    private static var memoryRecord: Set<String>?

    private static var recorded: Set<String> {
        get {
            if let memoryRecord { return memoryRecord }
            let stored = Set(UserDefaults.standard.stringArray(forKey: DefaultsKey.menuBarManagerDisallowed) ?? [])
            memoryRecord = stored
            return stored
        }
        set {
            memoryRecord = newValue
            if newValue.isEmpty {
                UserDefaults.standard.removeObject(forKey: DefaultsKey.menuBarManagerDisallowed)
            } else {
                UserDefaults.standard.set(newValue.sorted(), forKey: DefaultsKey.menuBarManagerDisallowed)
            }
        }
    }

    static var hasRecord: Bool { !recorded.isEmpty }

    /// Keeps exactly `concealed` off the bar, as far as this app is
    /// concerned. Returns the applications macOS keeps no switch for yet: an
    /// app that never drew an icon has none, so the caller tries again later.
    @discardableResult
    static func apply(concealed: Set<String>) throws -> Set<String> {
        let array = try Preferences.read()
        let states = MenuBarTrackedApplications.allowedStates(in: array)
        let plan = MenuBarTrackedApplications.plan(
            concealed: concealed, states: states, recorded: recorded,
            switchFor: { switchIdentifier(for: $0, states: states) })
        // Recorded before writing: should the app die between the two, the
        // next launch turns these back on, and each was on a moment ago.
        recorded = recorded.union(plan.disallow)
        let off = MenuBarTrackedApplications.settingAllowed(false, for: plan.disallow, in: array)
        let on = MenuBarTrackedApplications.settingAllowed(true, for: plan.allow, in: off.array)
        if !off.changed.isEmpty || !on.changed.isEmpty {
            try Preferences.write(on.array)
            if !off.changed.isEmpty {
                log.notice("hidden: \(off.changed.sorted().joined(separator: " "), privacy: .public)")
            }
            if !on.changed.isEmpty {
                log.notice("shown again: \(on.changed.sorted().joined(separator: " "), privacy: .public)")
            }
        }
        recorded = plan.recorded
        return plan.untracked
    }

    /// Turns back on every switch this app turned off, in this run or an
    /// earlier one. When the list cannot be read the record is kept, so the
    /// next launch tries again.
    static func releaseAll() {
        let toAllow = recorded
        guard !toAllow.isEmpty else { return }
        guard #available(macOS 27, *) else { return }
        do {
            let array = try Preferences.read()
            let on = MenuBarTrackedApplications.settingAllowed(true, for: toAllow, in: array)
            if !on.changed.isEmpty {
                try Preferences.write(on.array)
                log.notice("shown again: \(on.changed.sorted().joined(separator: " "), privacy: .public)")
            }
            recorded = []
        } catch {
            log.error("could not show \(toAllow.sorted().joined(separator: " "), privacy: .public) again: \(String(describing: error), privacy: .public)")
        }
    }

    /// The identifier macOS keeps the switch under for an application's
    /// icon: its own when it has one, else that of the application its
    /// process lives inside.
    private static func switchIdentifier(for bundleID: String, states: [String: Bool]) -> String {
        guard states[bundleID] == nil,
              let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first,
              let path = running.bundleURL?.path,
              let enclosing = MenuBarManagerSupport.outermostApplicationPath(of: path),
              enclosing != path,
              let enclosingID = Bundle(path: enclosing)?.bundleIdentifier,
              states[enclosingID] != nil
        else { return bundleID }
        return enclosingID
    }

    /// CoreFoundation's container-aware preference calls, looked up at first
    /// use. They are private, so their absence is an answer, not a crash.
    private struct Preferences {
        typealias Copy = @convention(c) (CFString, CFString, CFString, CFString, CFString)
            -> Unmanaged<CFPropertyList>?
        typealias SetValue = @convention(c) (CFString, CFPropertyList?, CFString, CFString, CFString, CFString) -> Void
        typealias Synchronize = @convention(c) (CFString, CFString, CFString, CFString) -> Bool

        let copy: Copy
        let set: SetValue
        let synchronize: Synchronize

        static let shared: Preferences? = {
            guard let handle = dlopen("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation", RTLD_NOW),
                  let copy = dlsym(handle, "_CFPreferencesCopyValueWithContainer"),
                  let set = dlsym(handle, "_CFPreferencesSetValueWithContainer"),
                  let synchronize = dlsym(handle, "_CFPreferencesSynchronizeWithContainer")
            else { return nil }
            return Preferences(copy: unsafeBitCast(copy, to: Copy.self),
                               set: unsafeBitCast(set, to: SetValue.self),
                               synchronize: unsafeBitCast(synchronize, to: Synchronize.self))
        }()

        static let key = "trackedApplications" as CFString
        static let applicationID = "group.com.apple.controlcenter" as CFString

        static var container: CFString {
            (NSHomeDirectory() + "/Library/Group Containers/group.com.apple.controlcenter") as CFString
        }

        static func read() throws -> [Any] {
            guard let shared else { throw Failure.unavailable }
            guard let value = shared.copy(key, applicationID, kCFPreferencesCurrentUser,
                                          kCFPreferencesAnyHost, container)?.takeRetainedValue(),
                  let data = value as? Data,
                  let array = MenuBarTrackedApplications.decode(data)
            else { throw Failure.unreadable }
            return array
        }

        static func write(_ array: [Any]) throws {
            guard let shared else { throw Failure.unavailable }
            let data = try MenuBarTrackedApplications.encode(array)
            shared.set(key, data as CFData, applicationID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost, container)
            guard shared.synchronize(applicationID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost, container) else {
                throw Failure.notSynchronized
            }
        }
    }
}
