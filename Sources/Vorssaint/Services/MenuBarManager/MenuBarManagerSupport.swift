// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation

/// Where a menu bar icon sits relative to the manager's dividers. Icons left
/// of the divider are hidden until asked for; icons left of the optional
/// second divider stay hidden even then.
enum MenuBarSection: String, CaseIterable {
    case visible, hidden, alwaysHidden
}

/// A user-named group of menu bar icons.
struct MenuBarCategory: Codable, Equatable, Identifiable {
    var id: String
    var name: String
}

/// The categories and which icon belongs to which. Icons are named by
/// `MenuBarManagerSupport.itemKey`, so an assignment follows the app rather
/// than a position in the bar.
struct MenuBarCategoryLayout: Codable, Equatable {
    var categories: [MenuBarCategory] = []
    var assignments: [String: String] = [:]

    func categoryID(for itemID: String) -> String? {
        guard let id = assignments[itemID], categories.contains(where: { $0.id == id }) else { return nil }
        return id
    }

    /// False when the name is empty, already taken, or the list is full.
    @discardableResult
    mutating func addCategory(named rawName: String, id: String = UUID().uuidString) -> Bool {
        let name = MenuBarManagerSupport.sanitizedCategoryName(rawName)
        guard !name.isEmpty, categories.count < MenuBarManagerSupport.maxCategories,
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

/// What the rest of the app may ask of the manager without bringing its
/// service to life. Main thread only.
enum MenuBarManagerState {
    /// True while the manager keeps part of the menu bar off screen, so an
    /// icon that is not on screen may simply be in the hidden section.
    static var isHidingItems = false
    /// Shows the hidden sections for a moment; nil while the manager is off.
    static var reveal: (() -> Void)?
}

/// The decisions behind the menu bar manager, kept free of AppKit so they can
/// be tested: which section an icon is in, where a drag has to end, how the
/// categories are stored.
enum MenuBarManagerSupport {
    /// A status item this long pushes everything on its left off the screen.
    static let expandedLength: CGFloat = 10_000

    static let toggleAutosaveName = "VorssaintMenuBarToggle"
    static let dividerAutosaveName = "VorssaintMenuBarDivider"
    static let alwaysHiddenAutosaveName = "VorssaintMenuBarAlwaysHidden"
    static let controlAutosaveNames = [toggleAutosaveName, dividerAutosaveName, alwaysHiddenAutosaveName]

    static let maxCategories = 12
    static let maxCategoryNameLength = 40

    /// Seconds before the hidden section closes again; zero keeps it open.
    static let rehideChoices = [0, 5, 10, 15, 30, 60]
    static let defaultRehideSeconds = 10

    static func sanitizedRehideSeconds(_ value: Int) -> Int {
        rehideChoices.contains(value) ? value : defaultRehideSeconds
    }

    /// The system-wide spacing preferences every status item reads at launch.
    static let spacingKey = "NSStatusItemSpacing"
    static let paddingKey = "NSStatusItemSelectionPadding"
    static let spacingRange = 0...24

    /// nil means the preference is unset and macOS uses its own spacing.
    static func sanitizedSpacing(_ value: Int?) -> Int? {
        guard let value else { return nil }
        return min(max(value, spacingRange.lowerBound), spacingRange.upperBound)
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

    // MARK: Sections

    /// An icon is hidden when it sits left of the divider, and always hidden
    /// when it also sits left of the second divider. This holds whether or
    /// not a divider is stretched: a stretched divider only moves its own
    /// left edge, and everything hidden, further left.
    static func section(midX: CGFloat, dividerMinX: CGFloat?, alwaysHiddenMinX: CGFloat?) -> MenuBarSection {
        if let alwaysHiddenMinX, midX < alwaysHiddenMinX { return .alwaysHidden }
        if let dividerMinX, midX < dividerMinX { return .hidden }
        return .visible
    }

    /// Stretching the divider is only safe while the arrow that brings the
    /// icons back sits on its right; otherwise the arrow would leave with them.
    static func dividerIsLeftOfToggle(toggleMinX: CGFloat, dividerMaxX: CGFloat) -> Bool {
        dividerMaxX <= toggleMinX + 1
    }

    /// The second divider only works from the left of the first.
    static func alwaysHiddenIsLeftOfDivider(alwaysHiddenMaxX: CGFloat, dividerMinX: CGFloat) -> Bool {
        alwaysHiddenMaxX <= dividerMinX + 1
    }

    /// Whether the pointer rests on the status half of the menu bar.
    static func isInStatusBand(point: CGPoint, screenFrame: CGRect, barHeight: CGFloat) -> Bool {
        guard barHeight > 0, point.x >= screenFrame.midX, point.x <= screenFrame.maxX else { return false }
        return point.y >= screenFrame.maxY - barHeight && point.y <= screenFrame.maxY
    }

    // MARK: Moving

    enum Placement: Equatable {
        case before, after
    }

    struct MovePlan: Equatable {
        let anchor: CGRect
        let placement: Placement
    }

    /// Which neighbour an icon has to end up beside to change section, with
    /// every section showing. nil when it is already there or the section
    /// does not exist.
    static func sectionMove(from current: MenuBarSection, to target: MenuBarSection,
                            divider: CGRect, alwaysHidden: CGRect?) -> MovePlan? {
        guard current != target else { return nil }
        switch target {
        case .visible:
            return MovePlan(anchor: divider, placement: .after)
        case .hidden:
            if current == .alwaysHidden, let alwaysHidden {
                return MovePlan(anchor: alwaysHidden, placement: .after)
            }
            return MovePlan(anchor: divider, placement: .before)
        case .alwaysHidden:
            guard let alwaysHidden else { return nil }
            return MovePlan(anchor: alwaysHidden, placement: .before)
        }
    }

    /// Where the middle of the dragged icon has to be let go. The bar closes
    /// the gap the icon leaves, so only what lies between its old and new
    /// place shifts: coming from the left the anchor stays put and the icon
    /// lands against its near edge; coming from the right the anchor itself
    /// shifts by the icon's width.
    static func dropCenterX(moving: CGRect, plan: MovePlan) -> CGFloat {
        let half = moving.width / 2
        let fromLeft = moving.midX < plan.anchor.midX
        switch plan.placement {
        case .before: return fromLeft ? plan.anchor.minX - half : plan.anchor.minX + half
        case .after: return fromLeft ? plan.anchor.maxX - half : plan.anchor.maxX + half
        }
    }

    // MARK: Categories

    static func sanitizedCategoryName(_ name: String) -> String {
        let collapsed = name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return String(collapsed.prefix(maxCategoryNameLength))
    }

    static func sanitized(_ layout: MenuBarCategoryLayout) -> MenuBarCategoryLayout {
        var result = MenuBarCategoryLayout()
        for category in layout.categories where !category.id.isEmpty {
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
