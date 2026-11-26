// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum MenuBarManagerTests {
    static func run(_ suite: TestSuite) {
        categories(suite)
        storage(suite)
        identity(suite)
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
                     && layout.categoryID(for: "com.ghost|#0") == nil && layout.assignments.count == 2,
                     "icons join existing categories only")

        let order = ["com.spotify|#0", "com.apple.MenuBarAgent|clock", "com.docker|#0"]
        suite.expect(MenuBarManagerSupport.groups(itemIDs: order, layout: layout) == [
            .init(categoryID: "dev", itemIDs: ["com.docker|#0"]),
            .init(categoryID: "media", itemIDs: ["com.spotify|#0"]),
            .init(categoryID: nil, itemIDs: ["com.apple.MenuBarAgent|clock"]),
        ], "the dropdown lists categories in their own order with unclaimed icons last")
        suite.expect(MenuBarManagerSupport.groups(itemIDs: ["com.docker|#0"], layout: layout)
                     == [.init(categoryID: "dev", itemIDs: ["com.docker|#0"])],
                     "categories without an icon on the bar are left out of the dropdown")
        suite.expect(MenuBarManagerSupport.groups(itemIDs: order, layout: MenuBarCategoryLayout())
                     == [.init(categoryID: nil, itemIDs: order)],
                     "without categories the dropdown is one plain list in bar order")

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
        for index in 0..<(MenuBarManagerSupport.maxCategories + 3) { full.addCategory(named: "Category \(index)") }
        suite.expect(full.categories.count == MenuBarManagerSupport.maxCategories, "the category list is capped")
        suite.expect(MenuBarManagerSupport.sanitizedCategoryName(String(repeating: "x", count: 90)).count
                     == MenuBarManagerSupport.maxCategoryNameLength, "a category name is capped")
    }

    private static func storage(_ suite: TestSuite) {
        var layout = MenuBarCategoryLayout()
        layout.addCategory(named: "Dev", id: "dev")
        layout.assign(itemID: "com.docker|#0", to: "dev")
        suite.expect(MenuBarManagerSupport.decodeLayout(MenuBarManagerSupport.encodeLayout(layout)) == layout,
                     "categories survive being saved")
        suite.expect(MenuBarManagerSupport.decodeLayout("") == MenuBarCategoryLayout()
                     && MenuBarManagerSupport.decodeLayout("{not json") == MenuBarCategoryLayout(),
                     "a missing or damaged save starts empty instead of failing")
        let stale = #"{"assignments":{"a|#0":"gone","b|#0":"dev"},"categories":[{"id":"dev","name":"Dev"},{"id":"dev","name":"Twin"}],"sections":{"x":"hidden"}}"#
        let cleaned = MenuBarManagerSupport.decodeLayout(stale)
        suite.expect(cleaned.categories == [MenuBarCategory(id: "dev", name: "Dev")]
                     && cleaned.assignments == ["b|#0": "dev"],
                     "a save is cleaned of twin categories and icons pointing nowhere, and keys it no longer uses are ignored")

        suite.expect(Defaults.registeredDefaults[DefaultsKey.menuBarManagerEnabled] as? Bool == false,
                     "the dropdown ships switched off")
        let backup = SettingsBackupSupport.exportKeys()
        suite.expect(backup.contains(DefaultsKey.menuBarManagerEnabled)
                     && backup.contains(DefaultsKey.menuBarManagerCategories),
                     "the switch and the categories travel in a settings backup")
        suite.expect(AppFeature.menuBarManager.enabledKeys == [DefaultsKey.menuBarManagerEnabled]
                     && !AppFeature.menuBarManager.installedByDefault
                     && AppFeature.menuBarManager.settingsDestination == FeatureSettingsDestination(.menuBarManager)
                     && FeatureVisibilitySupport.features(for: .menuBarManager) == [.menuBarManager],
                     "the dropdown is opt-in and has a Settings page of its own")
        for language in AppLanguage.allCases {
            suite.expect(FeatureStrings.menuBarManager(language).requiresMacOS27.contains("27"),
                         "the macOS requirement names the version in \(language.rawValue)")
        }
    }

    private static func identity(_ suite: TestSuite) {
        suite.expect(MenuBarManagerSupport.itemKey(bundleID: "com.docker.docker", appName: "Docker",
                                                   identifier: nil, index: 1) == "com.docker.docker|#1"
                     && MenuBarManagerSupport.itemKey(bundleID: "com.apple.MenuBarAgent", appName: "MenuBarAgent",
                                                      identifier: "com.apple.menuextra.wifi", index: 4)
                        == "com.apple.MenuBarAgent|com.apple.menuextra.wifi"
                     && MenuBarManagerSupport.itemKey(bundleID: nil, appName: "Helper", identifier: " ", index: 0)
                        == "Helper|#0",
                     "an icon is named by its app and its own identifier, or its place when it has none")
        suite.expect(MenuBarManagerSupport.displayTitle(title: nil, description: "Wi-Fi, connected, 3 bars",
                                                        appName: "MenuBarAgent") == "Wi-Fi"
                     && MenuBarManagerSupport.displayTitle(title: " ", description: nil, appName: "Docker") == "Docker"
                     && MenuBarManagerSupport.displayTitle(title: "Sync", description: "Other", appName: "App") == "Sync",
                     "an icon is called by its title, then its description without the live state, then its app")
        suite.expect(MenuBarManagerSupport.systemSymbol(forIdentifier: "com.apple.menuextra.wifi") == "wifi"
                     && MenuBarManagerSupport.systemSymbol(forIdentifier: "Item-0") == nil
                     && MenuBarManagerSupport.systemSymbol(forIdentifier: nil) == nil,
                     "system icons get a symbol of their own and other icons keep their app's")
    }
}
