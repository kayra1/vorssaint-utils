// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// A user-named group of menu bar icons.
struct MenuBarCategory: Codable, Equatable, Identifiable {
    var id: String
    var name: String
}

/// The categories, which icon belongs to which, and which apps are kept out
/// of the menu bar. Icons are named by `MenuBarManagerSupport.itemKey` and
/// apps by bundle identifier, so both follow the app rather than a place on
/// the bar.
struct MenuBarCategoryLayout: Codable, Equatable {
    var categories: [MenuBarCategory] = []
    /// Icon key to category id.
    var assignments: [String: String] = [:]
    /// Apps whose icons are kept out of the menu bar. macOS 27 hides whole
    /// apps, never single icons.
    var hiddenApps: Set<String> = []

    init(categories: [MenuBarCategory] = [], assignments: [String: String] = [:],
         hiddenApps: Set<String> = []) {
        self.categories = categories
        self.assignments = assignments
        self.hiddenApps = hiddenApps
    }

    // Saves written before hiding existed have no `hiddenApps` key.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        categories = try container.decodeIfPresent([MenuBarCategory].self, forKey: .categories) ?? []
        assignments = try container.decodeIfPresent([String: String].self, forKey: .assignments) ?? [:]
        hiddenApps = try container.decodeIfPresent(Set<String>.self, forKey: .hiddenApps) ?? []
    }

    func isHidden(_ bundleID: String) -> Bool {
        hiddenApps.contains(bundleID)
    }

    mutating func setHidden(_ hidden: Bool, for bundleID: String) {
        guard !bundleID.isEmpty else { return }
        if hidden { hiddenApps.insert(bundleID) } else { hiddenApps.remove(bundleID) }
    }

    func categoryID(for itemID: String) -> String? {
        guard let id = assignments[itemID], categories.contains(where: { $0.id == id }) else { return nil }
        return id
    }

    /// False when the name is empty, already taken, or the list is full.
    @discardableResult
    mutating func addCategory(named rawName: String, id: String = UUID().uuidString) -> Bool {
        let name = MenuBarManagerSupport.sanitizedCategoryName(rawName)
        guard !name.isEmpty, !id.isEmpty, categories.count < MenuBarManagerSupport.maxCategories,
              !categories.contains(where: { $0.id == id }),
              !categories.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })
        else { return false }
        categories.append(MenuBarCategory(id: id, name: name))
        return true
    }

    mutating func renameCategory(id: String, to rawName: String) {
        let name = MenuBarManagerSupport.sanitizedCategoryName(rawName)
        guard !name.isEmpty, let index = categories.firstIndex(where: { $0.id == id }),
              !categories.contains(where: { $0.id != id && $0.name.caseInsensitiveCompare(name) == .orderedSame })
        else { return }
        categories[index].name = name
    }

    mutating func removeCategory(id: String) {
        categories.removeAll { $0.id == id }
        assignments = assignments.filter { $0.value != id }
    }

    mutating func assign(itemID: String, to categoryID: String?) {
        guard let categoryID, categories.contains(where: { $0.id == categoryID }) else {
            assignments.removeValue(forKey: itemID)
            return
        }
        assignments[itemID] = categoryID
    }
}

/// One menu bar icon as last seen on the bar. A hidden application publishes
/// nothing through Accessibility, so what the manager knows of its icons is
/// what it saw while they were showing.
struct MenuBarRememberedItem: Codable, Equatable {
    var key: String
    var title: String
    var appName: String
    var identifier: String?
}

/// The decisions behind the menu bar manager, kept free of AppKit so they can
/// be tested.
enum MenuBarManagerSupport {
    static let toggleAutosaveName = "VorssaintMenuBarToggle"

    /// The process that draws the system's own icons on macOS 27.
    static let menuBarAgentBundleID = "com.apple.MenuBarAgent"

    static let maxCategories = 12
    static let maxCategoryNameLength = 40
    static let maxRememberedPerApp = 8

    /// Apps that may never be hidden: the system's own icons, and this app,
    /// whose arrow opens the dropdown.
    static func canHide(bundleID: String, ownBundleID: String?) -> Bool {
        !bundleID.isEmpty && bundleID != menuBarAgentBundleID && bundleID != ownBundleID
    }

    /// The apps to keep off the bar right now. Apps shown for a moment, to
    /// open one of their icons, are left out.
    static func concealed(layout: MenuBarCategoryLayout, temporarilyShown: Set<String>,
                          ownBundleID: String?) -> Set<String> {
        Set(layout.hiddenApps.filter { canHide(bundleID: $0, ownBundleID: ownBundleID) })
            .subtracting(temporarilyShown)
    }

    /// The outermost application bundle a path lies in, for a helper whose
    /// menu bar switch belongs to the app around it (Docker Desktop's icon
    /// comes from a helper inside Docker.app). nil when the path is in no
    /// application bundle.
    static func outermostApplicationPath(of path: String) -> String? {
        var components: [String] = []
        for component in path.split(separator: "/", omittingEmptySubsequences: true) {
            components.append(String(component))
            if component.lowercased().hasSuffix(".app") {
                return "/" + components.joined(separator: "/")
            }
        }
        return nil
    }

    // MARK: Identity

    /// A stable name for one icon: the owning app, then the icon's own
    /// identifier when it has one, else its place among that app's icons.
    static func itemKey(bundleID: String?, appName: String, identifier: String?, index: Int) -> String {
        let owner = bundleID.flatMap { $0.isEmpty ? nil : $0 } ?? appName
        let identifier = identifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return owner + "|" + (identifier.isEmpty ? "#\(index)" : identifier)
    }

    /// The name shown for an icon. Descriptions often carry live state after
    /// a comma ("Wi-Fi, connected"), which is not part of the name.
    static func displayTitle(title: String?, description: String?, appName: String) -> String {
        for candidate in [title, description] {
            guard let candidate else { continue }
            let head = candidate.split(separator: ",", maxSplits: 1).first.map(String.init) ?? ""
            let trimmed = head.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return String(trimmed.prefix(60)) }
        }
        return appName
    }

    /// A symbol for the system's own icons, which all belong to one process
    /// and would otherwise share its generic app icon.
    static func systemSymbol(forIdentifier identifier: String?) -> String? {
        guard let identifier = identifier?.lowercased(), !identifier.isEmpty else { return nil }
        let table: [(String, String)] = [
            ("wifi", "wifi"), ("bluetooth", "dot.radiowaves.left.and.right"),
            ("battery", "battery.75percent"), ("clock", "clock"),
            ("sound", "speaker.wave.2"), ("volume", "speaker.wave.2"),
            ("focus", "moon"), ("donotdisturb", "moon"),
            ("nowplaying", "play.circle"), ("display", "display"),
            ("screenmirroring", "rectangle.on.rectangle"), ("airdrop", "dot.radiowaves.forward"),
            ("spotlight", "magnifyingglass"), ("siri", "mic"),
            ("textinput", "keyboard"), ("keyboard", "keyboard"),
            ("timemachine", "clock.arrow.circlepath"), ("user", "person.circle"),
            ("vpn", "network"), ("accessibility", "accessibility"),
            ("controlcenter", "switch.2"), ("bentobox", "switch.2"),
        ]
        return table.first { identifier.contains($0.0) }?.1
    }

    // MARK: Storage

    static func sanitizedCategoryName(_ name: String) -> String {
        let collapsed = name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return String(collapsed.prefix(maxCategoryNameLength))
    }

    static func sanitized(_ layout: MenuBarCategoryLayout) -> MenuBarCategoryLayout {
        var result = MenuBarCategoryLayout()
        for category in layout.categories {
            result.addCategory(named: category.name, id: category.id)
        }
        let known = Set(result.categories.map(\.id))
        result.assignments = layout.assignments.filter { !$0.key.isEmpty && known.contains($0.value) }
        result.hiddenApps = layout.hiddenApps.filter { !$0.isEmpty }
        return result
    }

    static func decodeLayout(_ raw: String) -> MenuBarCategoryLayout {
        guard let data = raw.data(using: .utf8),
              let layout = try? JSONDecoder().decode(MenuBarCategoryLayout.self, from: data)
        else { return MenuBarCategoryLayout() }
        return sanitized(layout)
    }

    static func encodeLayout(_ layout: MenuBarCategoryLayout) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(sanitized(layout)) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func decodeRemembered(_ raw: String) -> [String: [MenuBarRememberedItem]] {
        guard let data = raw.data(using: .utf8),
              let stored = try? JSONDecoder().decode([String: [MenuBarRememberedItem]].self, from: data)
        else { return [:] }
        return stored.filter { !$0.key.isEmpty && !$0.value.isEmpty }
            .mapValues { Array($0.prefix(maxRememberedPerApp)) }
    }

    static func encodeRemembered(_ items: [String: [MenuBarRememberedItem]]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(items.filter { !$0.value.isEmpty }) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    struct CategoryGroup: Equatable {
        /// nil gathers the icons no category claims.
        let categoryID: String?
        let itemIDs: [String]
    }

    /// The icons under each category, in the order given, with the unclaimed
    /// ones last. Empty groups are left out.
    static func groups(itemIDs: [String], layout: MenuBarCategoryLayout) -> [CategoryGroup] {
        var result: [CategoryGroup] = []
        for category in layout.categories {
            let members = itemIDs.filter { layout.categoryID(for: $0) == category.id }
            if !members.isEmpty { result.append(CategoryGroup(categoryID: category.id, itemIDs: members)) }
        }
        let loose = itemIDs.filter { layout.categoryID(for: $0) == nil }
        if !loose.isEmpty { result.append(CategoryGroup(categoryID: nil, itemIDs: loose)) }
        return result
    }
}

/// Pure rules for macOS 27's own list of applications allowed in the menu bar.
///
/// The switch "Allow in the Menu Bar" (System Settings > Menu Bar) is kept by
/// MenuBarAgent in the `trackedApplications` preference of the
/// `group.com.apple.controlcenter` container: data holding a binary property
/// list, a flat array alternating key, value, key, value. A key is
/// `{"bundle": {"_0": "<bundle id>"}}` (other key shapes exist for binaries
/// without a team signature); a value carries `isAllowed`. Only `isAllowed`
/// under bundle keys is ever changed; everything else goes back exactly as it
/// came. Format as measured by Ice on macOS 27.0.1
/// (https://github.com/jordanbaird/Ice, GPL-3.0).
enum MenuBarTrackedApplications {
    struct Entry: Equatable {
        /// nil for a key that is not a bundle key.
        let bundleID: String?
        let isAllowed: Bool?
        /// Where the value stands in the flat array; its key is just before.
        let valueIndex: Int
    }

    static func entries(in array: [Any]) -> [Entry] {
        guard array.count >= 2 else { return [] }
        return stride(from: 0, to: array.count - 1, by: 2).map { keyIndex in
            let value = array[keyIndex + 1] as? [String: Any]
            return Entry(bundleID: bundleID(ofKey: array[keyIndex]),
                         isAllowed: value?["isAllowed"] as? Bool,
                         valueIndex: keyIndex + 1)
        }
    }

    static func bundleID(ofKey key: Any) -> String? {
        guard let key = key as? [String: Any], key.count == 1,
              let bundle = key["bundle"] as? [String: Any] else { return nil }
        return bundle["_0"] as? String
    }

    /// The current switch of each bundle in the list.
    static func allowedStates(in array: [Any]) -> [String: Bool] {
        var states = [String: Bool]()
        for entry in entries(in: array) {
            guard let bundleID = entry.bundleID, let isAllowed = entry.isAllowed else { continue }
            states[bundleID] = (states[bundleID] ?? false) || isAllowed
        }
        return states
    }

    /// The list with the switch set for the given bundles, and the bundles it
    /// actually changed.
    static func settingAllowed(_ allowed: Bool, for bundleIDs: Set<String>,
                               in array: [Any]) -> (array: [Any], changed: Set<String>) {
        guard !bundleIDs.isEmpty else { return (array, []) }
        var result = array
        var changed = Set<String>()
        for entry in entries(in: array) {
            guard let bundleID = entry.bundleID, bundleIDs.contains(bundleID),
                  let isAllowed = entry.isAllowed, isAllowed != allowed,
                  var value = array[entry.valueIndex] as? [String: Any] else { continue }
            value["isAllowed"] = allowed
            result[entry.valueIndex] = value
            changed.insert(bundleID)
        }
        return (result, changed)
    }

    static func decode(_ data: Data) -> [Any]? {
        try? PropertyListSerialization.propertyList(from: data, format: nil) as? [Any]
    }

    static func encode(_ array: [Any]) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: array, format: .binary, options: 0)
    }

    struct Plan: Equatable {
        /// Switches to turn off now.
        let disallow: Set<String>
        /// Switches this app turned off earlier that may go back on.
        let allow: Set<String>
        /// What stays recorded as turned off by this app.
        let recorded: Set<String>
        /// Concealed apps macOS keeps no switch for yet; retried later.
        let untracked: Set<String>
    }

    /// What to change so that exactly `concealed` is kept off the bar by this
    /// app. Only switches this app turned off (`recorded`) are ever turned
    /// back on: one the person turned off in System Settings stays theirs.
    /// `switchFor` maps an application to the identifier its switch is kept
    /// under.
    static func plan(concealed: Set<String>, states: [String: Bool], recorded: Set<String>,
                     switchFor: (String) -> String) -> Plan {
        let switches = Set(concealed.map(switchFor))
        let disallow = Set(switches.filter { states[$0] == true })
        let allow = recorded.subtracting(switches)
        let stillOff = recorded.intersection(switches).filter { states[$0] == false }
        return Plan(disallow: disallow, allow: allow, recorded: stillOff.union(disallow),
                    untracked: Set(concealed.filter { states[switchFor($0)] == nil }))
    }
}
