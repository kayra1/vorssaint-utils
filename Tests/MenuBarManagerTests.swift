// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum MenuBarManagerTests {
    static func run(_ suite: TestSuite) {
        categories(suite)
        storage(suite)
        identity(suite)
        hiding(suite)
        switches(suite)
        trackedApplications(suite)
    }

    private static func hiding(_ suite: TestSuite) {
        var layout = MenuBarCategoryLayout()
        layout.setHidden(true, for: "com.docker.docker")
        layout.setHidden(true, for: "com.spotify.client")
        layout.setHidden(true, for: "com.vorssaint.utils")
        layout.setHidden(true, for: MenuBarManagerSupport.menuBarAgentBundleID)
        layout.setHidden(true, for: "")
        func concealed(_ shown: Set<String> = []) -> Set<String> {
            MenuBarManagerSupport.concealed(layout: layout, temporarilyShown: shown, ownBundleID: "com.vorssaint.utils")
        }
        suite.expect(concealed() == ["com.docker.docker", "com.spotify.client"],
                     "hidden apps stay off the bar, but never this app or the system's own icons")
        suite.expect(concealed(["com.spotify.client"]) == ["com.docker.docker"],
                     "an app opened from the dropdown shows for that moment")
        layout.setHidden(false, for: "com.docker.docker")
        suite.expect(concealed() == ["com.spotify.client"] && !layout.isHidden("com.docker.docker"),
                     "turning an app back on brings it back")
        suite.expect(MenuBarManagerSupport.decodeLayout(MenuBarManagerSupport.encodeLayout(layout)) == layout,
                     "hidden apps survive being saved")
        suite.expect(MenuBarManagerSupport.canHide(bundleID: "com.docker.docker", ownBundleID: "com.vorssaint.utils")
                     && !MenuBarManagerSupport.canHide(bundleID: "com.vorssaint.utils", ownBundleID: "com.vorssaint.utils")
                     && !MenuBarManagerSupport.canHide(bundleID: MenuBarManagerSupport.menuBarAgentBundleID,
                                                       ownBundleID: nil)
                     && !MenuBarManagerSupport.canHide(bundleID: "", ownBundleID: nil),
                     "every app but this one and the system can be hidden")

        let remembered = ["com.docker": [MenuBarRememberedItem(key: "com.docker|#0", title: "Docker",
                                                               appName: "Docker Desktop", identifier: nil)]]
        suite.expect(MenuBarManagerSupport.decodeRemembered(MenuBarManagerSupport.encodeRemembered(remembered))
                     == remembered && MenuBarManagerSupport.decodeRemembered("[1,2]").isEmpty,
                     "the icons of hidden apps are remembered across launches")
        suite.expect(MenuBarManagerSupport.outermostApplicationPath(
                        of: "/Applications/Docker.app/Contents/MacOS/com.docker.helper.app/Contents/MacOS/x")
                        == "/Applications/Docker.app"
                     && MenuBarManagerSupport.outermostApplicationPath(of: "/usr/local/bin/tool") == nil,
                     "a helper belongs to the outermost application around it")
    }

    private static func switches(_ suite: TestSuite) {
        typealias Rules = MenuBarTrackedApplications
        let identity: (String) -> String = { $0 }
        let first = Rules.plan(concealed: ["a", "c"], states: ["a": true, "b": true, "c": false],
                               recorded: [], switchFor: identity)
        suite.expect(first.disallow == ["a"] && first.allow.isEmpty && first.recorded == ["a"],
                     "only switches that are on get turned off, and each one is recorded")
        suite.expect(!first.recorded.contains("c"),
                     "a switch the person turned off is never recorded, so it is never turned back on")
        let showing = Rules.plan(concealed: [], states: ["a": false, "c": false], recorded: ["a"], switchFor: identity)
        suite.expect(showing.allow == ["a"] && showing.disallow.isEmpty && showing.recorded.isEmpty,
                     "showing turns back on exactly what this app turned off")
        let resisted = Rules.plan(concealed: ["a"], states: ["a": true], recorded: ["a"], switchFor: identity)
        suite.expect(resisted.disallow == ["a"] && resisted.recorded == ["a"],
                     "a hidden app switched back on in System Settings is hidden again")
        let untracked = Rules.plan(concealed: ["new"], states: ["a": true], recorded: [], switchFor: identity)
        suite.expect(untracked.disallow.isEmpty && untracked.untracked == ["new"],
                     "an app without a switch yet is reported for a later try")
        let helper = Rules.plan(concealed: ["com.docker.helper"], states: ["com.docker.docker": true], recorded: [],
                                switchFor: { $0 == "com.docker.helper" ? "com.docker.docker" : $0 })
        suite.expect(helper.disallow == ["com.docker.docker"] && helper.untracked.isEmpty,
                     "a helper's icon is hidden through the switch of the app it lives in")
    }

    private static func trackedApplications(_ suite: TestSuite) {
        typealias Rules = MenuBarTrackedApplications
        func key(_ id: String) -> [String: Any] { ["bundle": ["_0": id]] }
        let adhoc: [String: Any] = ["adhocBinary": ["_0": ["relative": "file:///tmp/tool"]]]
        let list: [Any] = [
            key("com.docker.docker"), ["location": key("com.docker.docker"), "isAllowed": true,
                                       "menuItemLocations": [key("com.docker.docker")]],
            adhoc, ["location": adhoc, "isAllowed": true],
            key("com.spotify.client"), ["location": key("com.spotify.client"), "isAllowed": false],
            key("com.example.flagless"), ["location": key("com.example.flagless")],
        ]
        suite.expect(Rules.allowedStates(in: list) == ["com.docker.docker": true, "com.spotify.client": false],
                     "switches are read from bundle keys only, and entries without one are skipped")
        let off = Rules.settingAllowed(false, for: ["com.docker.docker", "com.spotify.client", "missing"], in: list)
        suite.expect(off.changed == ["com.docker.docker"], "only switches that differ are changed")
        suite.expect(Rules.allowedStates(in: off.array)["com.docker.docker"] == false
                     && off.array.count == list.count
                     && ((off.array[1] as? [String: Any])?["menuItemLocations"] as? [Any])?.count == 1
                     && (off.array[3] as? [String: Any])?["isAllowed"] as? Bool == true
                     && (off.array[7] as? [String: Any])?["isAllowed"] == nil,
                     "everything but the changed switch goes back exactly as it came")
        let decoded = (try? Rules.encode(off.array)).flatMap(Rules.decode)
        suite.expect(decoded.map(Rules.allowedStates(in:)) == Rules.allowedStates(in: off.array),
                     "the list survives the binary property list round trip MenuBarAgent reads")
        suite.expect(Rules.decode(Data("not a plist".utf8)) == nil && Rules.entries(in: [key("odd")]).isEmpty,
                     "an unreadable or unpaired list yields nothing to change")
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
                     && cleaned.assignments == ["b|#0": "dev"] && cleaned.hiddenApps.isEmpty,
                     "a save is cleaned of twin categories and icons pointing nowhere, and keys it no longer uses are ignored")

        suite.expect(Defaults.registeredDefaults[DefaultsKey.menuBarManagerEnabled] as? Bool == false,
                     "the dropdown ships switched off")
        let backup = SettingsBackupSupport.exportKeys()
        suite.expect(backup.contains(DefaultsKey.menuBarManagerEnabled)
                     && backup.contains(DefaultsKey.menuBarManagerCategories)
                     && !backup.contains(DefaultsKey.menuBarManagerDisallowed)
                     && !backup.contains(DefaultsKey.menuBarManagerRememberedItems),
                     "choices travel in a backup; this Mac's switch record and seen icons do not")
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
