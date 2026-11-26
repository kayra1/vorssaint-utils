// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// A user-named group of menu bar icons.
struct MenuBarCategory: Codable, Equatable, Identifiable {
    var id: String
    var name: String
}

/// The categories and which icon belongs to which. Icons are named by
/// `MenuBarManagerSupport.itemKey`, so an assignment follows the app rather
/// than a place on the bar.
struct MenuBarCategoryLayout: Codable, Equatable {
    var categories: [MenuBarCategory] = []
    /// Icon key to category id.
    var assignments: [String: String] = [:]

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

/// The decisions behind the menu bar manager, kept free of AppKit so they can
/// be tested.
enum MenuBarManagerSupport {
    static let toggleAutosaveName = "VorssaintMenuBarToggle"

    /// The process that draws the system's own icons on macOS 27.
    static let menuBarAgentBundleID = "com.apple.MenuBarAgent"

    static let maxCategories = 12
    static let maxCategoryNameLength = 40

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
