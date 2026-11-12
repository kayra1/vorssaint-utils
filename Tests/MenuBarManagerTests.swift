// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation

enum MenuBarManagerTests {
    static func run(_ suite: TestSuite) {
        sections(suite)
        moves(suite)
        categories(suite)
        preferences(suite)
    }

    private static func sections(_ suite: TestSuite) {
        func section(_ x: CGFloat, divider: CGFloat? = 1000, always: CGFloat? = nil) -> MenuBarSection {
            MenuBarManagerSupport.section(midX: x, dividerMinX: divider, alwaysHiddenMinX: always)
        }
        suite.expect(section(1100) == .visible && section(900) == .hidden,
                     "an icon is hidden exactly when it sits left of the divider")
        suite.expect(section(900, always: 800) == .hidden && section(700, always: 800) == .alwaysHidden,
                     "the second divider splits the hidden icons")
        // A stretched divider keeps its right edge and moves its left edge,
        // and every hidden icon with it, far off screen.
        suite.expect(section(-9100, divider: -9000) == .hidden && section(1100, divider: -9000) == .visible,
                     "the split reads the same while the divider is stretched")
        suite.expect(section(100, divider: nil) == .visible,
                     "without a divider nothing counts as hidden")

        suite.expect(MenuBarManagerSupport.dividerIsLeftOfToggle(toggleMinX: 1000, dividerMaxX: 1000)
                     && MenuBarManagerSupport.dividerIsLeftOfToggle(toggleMinX: 1000, dividerMaxX: 980)
                     && !MenuBarManagerSupport.dividerIsLeftOfToggle(toggleMinX: 1000, dividerMaxX: 1030),
                     "hiding is refused while the divider would take the arrow with it")
        suite.expect(MenuBarManagerSupport.alwaysHiddenIsLeftOfDivider(alwaysHiddenMaxX: 900, dividerMinX: 900)
                     && !MenuBarManagerSupport.alwaysHiddenIsLeftOfDivider(alwaysHiddenMaxX: 950, dividerMinX: 900),
                     "the second divider only works from the left of the first")

        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        func inBand(_ x: CGFloat, _ y: CGFloat, height: CGFloat = 24) -> Bool {
            MenuBarManagerSupport.isInStatusBand(point: CGPoint(x: x, y: y), screenFrame: screen, barHeight: height)
        }
        suite.expect(inBand(1200, 890) && inBand(1440, 900) && inBand(720, 876),
                     "the status half of the menu bar counts as hovering")
        suite.expect(!inBand(300, 890) && !inBand(1200, 870) && !inBand(1500, 890) && !inBand(1200, 890, height: 0),
                     "the app menus, the desktop and other displays do not")
    }

    private static func moves(_ suite: TestSuite) {
        let divider = CGRect(x: 1000, y: 0, width: 10, height: 24)
        let always = CGRect(x: 800, y: 0, width: 10, height: 24)
        typealias Plan = MenuBarManagerSupport.MovePlan
        func plan(_ from: MenuBarSection, _ to: MenuBarSection, always: CGRect? = always) -> Plan? {
            MenuBarManagerSupport.sectionMove(from: from, to: to, divider: divider, alwaysHidden: always)
        }
        suite.expect(plan(.visible, .visible) == nil && plan(.hidden, .hidden) == nil,
                     "an icon already in the section is left alone")
        suite.expect(plan(.hidden, .visible) == Plan(anchor: divider, placement: .after)
                     && plan(.alwaysHidden, .visible) == Plan(anchor: divider, placement: .after),
                     "showing an icon lands it just right of the divider")
        suite.expect(plan(.visible, .hidden) == Plan(anchor: divider, placement: .before)
                     && plan(.alwaysHidden, .hidden) == Plan(anchor: always, placement: .after)
                     && plan(.alwaysHidden, .hidden, always: nil) == Plan(anchor: divider, placement: .before),
                     "hiding an icon enters the hidden section from the side it comes from")
        suite.expect(plan(.visible, .alwaysHidden) == Plan(anchor: always, placement: .before)
                     && plan(.visible, .alwaysHidden, always: nil) == nil,
                     "always hiding needs the second divider")

        // The bar packs its icons, so the drop point is the middle of the slot
        // the icon ends in once the gap it left has closed.
        let icon = CGRect(x: 1100, y: 0, width: 30, height: 24)
        let hiddenIcon = CGRect(x: 900, y: 0, width: 30, height: 24)
        func drop(_ moving: CGRect, _ anchor: CGRect, _ placement: MenuBarManagerSupport.Placement) -> CGFloat {
            MenuBarManagerSupport.dropCenterX(moving: moving, plan: Plan(anchor: anchor, placement: placement))
        }
        suite.expect(drop(icon, divider, .before) == 1015,
                     "coming from the right, the divider shifts and the icon takes its old place")
        suite.expect(drop(hiddenIcon, divider, .after) == 995,
                     "coming from the left, the divider shifts left and the icon ends against its old right edge")
        suite.expect(drop(hiddenIcon, divider, .before) == 985 && drop(icon, divider, .after) == 1025,
                     "a move that does not cross the anchor lands beside it where it stands")
    }

    private static func categories(_ suite: TestSuite) {
        var layout = MenuBarCategoryLayout()
        suite.expect(layout.addCategory(named: "  Dev   tools ", id: "dev")
                     && layout.categories == [MenuBarCategory(id: "dev", name: "Dev tools")],
                     "a category name loses stray spaces")
        suite.expect(!layout.addCategory(named: "dev TOOLS") && !layout.addCategory(named: "   ")
                     && !layout.addCategory(named: "Other", id: "dev") && layout.categories.count == 1,
                     "empty and duplicate categories are refused")
        suite.expect(layout.addCategory(named: "Media", id: "media"), "a second category is added")
        layout.assign(itemID: "com.docker|#0", to: "dev")
        layout.assign(itemID: "com.spotify|#0", to: "media")
        layout.assign(itemID: "com.ghost|#0", to: "missing")
        suite.expect(layout.categoryID(for: "com.docker|#0") == "dev"
                     && layout.categoryID(for: "com.ghost|#0") == nil
                     && layout.assignments.count == 2,
                     "icons join existing categories only")

        let order = ["com.spotify|#0", "com.apple.controlcenter|wifi", "com.docker|#0"]
        suite.expect(MenuBarManagerSupport.groups(itemIDs: order, layout: layout) == [
            .init(categoryID: "dev", itemIDs: ["com.docker|#0"]),
            .init(categoryID: "media", itemIDs: ["com.spotify|#0"]),
            .init(categoryID: nil, itemIDs: ["com.apple.controlcenter|wifi"]),
        ], "the panel lists categories in their own order with unclaimed icons last")
        suite.expect(MenuBarManagerSupport.groups(itemIDs: ["com.docker|#0"], layout: layout)
                     == [.init(categoryID: "dev", itemIDs: ["com.docker|#0"])],
                     "categories without a running icon are left out")

        let restored = MenuBarManagerSupport.decodeLayout(MenuBarManagerSupport.encodeLayout(layout))
        suite.expect(restored == layout, "categories survive being saved")
        suite.expect(MenuBarManagerSupport.decodeLayout("") == MenuBarCategoryLayout()
                     && MenuBarManagerSupport.decodeLayout("{not json") == MenuBarCategoryLayout(),
                     "a missing or damaged save starts empty instead of failing")
        let stale = #"{"assignments":{"a|#0":"gone","b|#0":"dev"},"categories":[{"id":"dev","name":"Dev"},{"id":"dev","name":"Twin"},{"id":"","name":"Nameless"}]}"#
        let cleaned = MenuBarManagerSupport.decodeLayout(stale)
        suite.expect(cleaned.categories == [MenuBarCategory(id: "dev", name: "Dev")]
                     && cleaned.assignments == ["b|#0": "dev"],
                     "a save is cleaned of twin categories and of icons pointing nowhere")

        layout.renameCategory(id: "dev", to: "Media")
        suite.expect(layout.categories.first?.name == "Dev tools", "a rename cannot take another category's name")
        layout.renameCategory(id: "dev", to: "Work")
        layout.removeCategory(id: "media")
        suite.expect(layout.categories == [MenuBarCategory(id: "dev", name: "Work")]
                     && layout.assignments == ["com.docker|#0": "dev"],
                     "removing a category releases its icons")
        layout.assign(itemID: "com.docker|#0", to: nil)
        suite.expect(layout.assignments.isEmpty, "an icon can leave its category")

        var full = MenuBarCategoryLayout()
        for index in 0..<(MenuBarManagerSupport.maxCategories + 3) {
            full.addCategory(named: "Category \(index)")
        }
        suite.expect(full.categories.count == MenuBarManagerSupport.maxCategories,
                     "the category list is capped")
        suite.expect(MenuBarManagerSupport.sanitizedCategoryName(String(repeating: "x", count: 90)).count
                     == MenuBarManagerSupport.maxCategoryNameLength,
                     "a category name is capped")
    }

    private static func preferences(_ suite: TestSuite) {
        suite.expect(MenuBarManagerSupport.itemKey(bundleID: "com.docker.docker", appName: "Docker",
                                                   identifier: nil, index: 1) == "com.docker.docker|#1"
                     && MenuBarManagerSupport.itemKey(bundleID: "com.apple.controlcenter", appName: "Control Center",
                                                      identifier: "com.apple.menuextra.wifi", index: 4)
                        == "com.apple.controlcenter|com.apple.menuextra.wifi"
                     && MenuBarManagerSupport.itemKey(bundleID: nil, appName: "Helper", identifier: " ", index: 0)
                        == "Helper|#0",
                     "an icon is named by its app and its own identifier, or its place when it has none")
        suite.expect(MenuBarManagerSupport.displayTitle(title: nil, description: "Wi-Fi, connected, 3 bars",
                                                        appName: "Control Center") == "Wi-Fi"
                     && MenuBarManagerSupport.displayTitle(title: " ", description: nil, appName: "Docker") == "Docker"
                     && MenuBarManagerSupport.displayTitle(title: "Sync", description: "Other", appName: "App") == "Sync",
                     "an icon is called by its title, then its description without the live state, then its app")
        suite.expect(MenuBarManagerSupport.systemSymbol(forIdentifier: "com.apple.menuextra.wifi") == "wifi"
                     && MenuBarManagerSupport.systemSymbol(forIdentifier: "com.apple.menuextra.clock") == "clock"
                     && MenuBarManagerSupport.systemSymbol(forIdentifier: "Item-0") == nil
                     && MenuBarManagerSupport.systemSymbol(forIdentifier: nil) == nil,
                     "system icons get a symbol of their own and other icons keep their app's")

        suite.expect(MenuBarManagerSupport.rehideChoices.allSatisfy {
            MenuBarManagerSupport.sanitizedRehideSeconds($0) == $0
        } && MenuBarManagerSupport.sanitizedRehideSeconds(7) == MenuBarManagerSupport.defaultRehideSeconds
            && MenuBarManagerSupport.sanitizedRehideSeconds(-1) == MenuBarManagerSupport.defaultRehideSeconds,
                     "the hide delay is one of the offered choices")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.menuBarManagerRehideSeconds] as? Int
                     == MenuBarManagerSupport.defaultRehideSeconds
                     && Defaults.registeredDefaults[DefaultsKey.menuBarManagerEnabled] as? Bool == false,
                     "the manager ships switched off with the default hide delay")
        suite.expect(MenuBarManagerSupport.sanitizedSpacing(nil) == nil
                     && MenuBarManagerSupport.sanitizedSpacing(-4) == 0
                     && MenuBarManagerSupport.sanitizedSpacing(12) == 12
                     && MenuBarManagerSupport.sanitizedSpacing(99) == 24,
                     "icon spacing stays in a usable range and can be handed back to macOS")

        let backup = SettingsBackupSupport.exportKeys()
        suite.expect([DefaultsKey.menuBarManagerEnabled, DefaultsKey.menuBarManagerShowOnHover,
                      DefaultsKey.menuBarManagerRehideSeconds, DefaultsKey.menuBarManagerAlwaysHidden,
                      DefaultsKey.menuBarManagerClickOpensCategories, DefaultsKey.menuBarManagerCategories]
                        .allSatisfy(backup.contains),
                     "the manager's choices and categories travel in a settings backup")
        suite.expect(AppFeature.menuBarManager.enabledKeys == [DefaultsKey.menuBarManagerEnabled]
                     && !AppFeature.menuBarManager.installedByDefault
                     && AppFeature.menuBarManager.settingsDestination == FeatureSettingsDestination(.menuBarManager)
                     && FeatureVisibilitySupport.features(for: .menuBarManager) == [.menuBarManager],
                     "the manager is opt-in and has a Settings page of its own")
        for language in AppLanguage.allCases {
            let strings = FeatureStrings.menuBarManager(language)
            suite.expect(String(format: strings.rehideSecondsFormat, 15).contains("15"),
                         "the hide delay names its seconds in \(language.rawValue)")
        }
    }
}
