// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation

enum MenuBarManagerTests {
    static func run(_ suite: TestSuite) {
        concealment(suite)
        switches(suite)
        trackedApplications(suite)
        categories(suite)
        storage(suite)
        identity(suite)
    }

    private static func concealment(_ suite: TestSuite) {
        var layout = MenuBarCategoryLayout()
        layout.setSection(.hidden, for: "com.docker.docker")
        layout.setSection(.alwaysHidden, for: "com.spotify.client")
        layout.setSection(.hidden, for: "com.vorssaint.utils")
        layout.setSection(.hidden, for: MenuBarManagerSupport.menuBarAgentBundleID)
        layout.setSection(.visible, for: "com.example.shown")
        func concealed(_ state: MenuBarRevealState, shown: Set<String> = []) -> Set<String> {
            MenuBarManagerSupport.concealed(layout: layout, state: state, temporarilyShown: shown,
                                            ownBundleID: "com.vorssaint.utils")
        }
        suite.expect(concealed(.allHidden) == ["com.docker.docker", "com.spotify.client"],
                     "closed, both hidden sections stay off the bar")
        suite.expect(concealed(.hiddenRevealed) == ["com.spotify.client"],
                     "the arrow brings back the hidden section but not the always hidden one")
        suite.expect(concealed(.allRevealed).isEmpty, "Option-click brings everything back")
        suite.expect(concealed(.allHidden, shown: ["com.spotify.client"]) == ["com.docker.docker"],
                     "an app opened from the panel shows for that moment")
        suite.expect(!concealed(.allHidden).contains("com.vorssaint.utils")
                     && !concealed(.allHidden).contains(MenuBarManagerSupport.menuBarAgentBundleID),
                     "the arrow's own app and the system icons are never hidden")
        suite.expect(layout.sections["com.example.shown"] == nil && layout.section(for: "com.example.shown") == .visible,
                     "visible is the absence of a choice, so new apps start visible")

        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        func inBand(_ x: CGFloat, _ y: CGFloat, height: CGFloat = 24) -> Bool {
            MenuBarManagerSupport.isInStatusBand(point: CGPoint(x: x, y: y), screenFrame: screen, barHeight: height)
        }
        suite.expect(inBand(1200, 890) && inBand(1440, 900) && inBand(720, 876),
                     "the status half of the menu bar counts as hovering")
        suite.expect(!inBand(300, 890) && !inBand(1200, 870) && !inBand(1500, 890) && !inBand(1200, 890, height: 0),
                     "the app menus, the desktop and other displays do not")
    }

    private static func switches(_ suite: TestSuite) {
        typealias Rules = MenuBarTrackedApplications
        let identity: (String) -> String = { $0 }
        let states = ["a": true, "b": true, "c": false, "d": false]

        let first = Rules.plan(concealed: ["a", "c"], states: states, recorded: [], switchFor: identity)
        suite.expect(first.disallow == ["a"] && first.allow.isEmpty && first.recorded == ["a"],
                     "only switches that are on get turned off, and each one is recorded")
        suite.expect(!first.recorded.contains("c"),
                     "a switch the person turned off is never recorded, so it is never turned back on")

        let showing = Rules.plan(concealed: [], states: ["a": false, "b": true, "c": false],
                                 recorded: ["a"], switchFor: identity)
        suite.expect(showing.disallow.isEmpty && showing.allow == ["a"] && showing.recorded.isEmpty,
                     "showing turns back on exactly what this app turned off")

        let resisted = Rules.plan(concealed: ["a"], states: ["a": true], recorded: ["a"], switchFor: identity)
        suite.expect(resisted.disallow == ["a"] && resisted.recorded == ["a"],
                     "a hidden app switched back on in System Settings is hidden again")

        let untracked = Rules.plan(concealed: ["new"], states: states, recorded: [], switchFor: identity)
        suite.expect(untracked.disallow.isEmpty && untracked.untracked == ["new"] && untracked.recorded.isEmpty,
                     "an app without a switch yet is reported for a later try")

        let helper = Rules.plan(concealed: ["com.docker.helper"], states: ["com.docker.docker": true],
                                recorded: [], switchFor: { $0 == "com.docker.helper" ? "com.docker.docker" : $0 })
        suite.expect(helper.disallow == ["com.docker.docker"] && helper.untracked.isEmpty,
                     "a helper's icon is hidden through the switch of the app it lives in")

        suite.expect(MenuBarManagerSupport.outermostApplicationPath(
                        of: "/Applications/Docker.app/Contents/MacOS/com.docker.helper.app/Contents/MacOS/x")
                        == "/Applications/Docker.app"
                     && MenuBarManagerSupport.outermostApplicationPath(of: "/Applications/Tool.app") == "/Applications/Tool.app"
                     && MenuBarManagerSupport.outermostApplicationPath(of: "/usr/local/bin/tool") == nil,
                     "a helper belongs to the outermost application around it")
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

        let data = try? Rules.encode(off.array)
        let decoded = data.flatMap(Rules.decode)
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
        ], "the panel lists categories in their own order with unclaimed icons last")

        layout.renameCategory(id: "dev", to: "Media")
        suite.expect(layout.categories.first?.name == "Dev tools", "a rename cannot take another category's name")
        layout.renameCategory(id: "dev", to: "Work")
        layout.removeCategory(id: "media")
        suite.expect(layout.categories == [MenuBarCategory(id: "dev", name: "Work")]
                     && layout.assignments == ["com.docker|#0": "dev"],
                     "removing a category releases its icons")

        var full = MenuBarCategoryLayout()
        for index in 0..<(MenuBarManagerSupport.maxCategories + 3) { full.addCategory(named: "Category \(index)") }
        suite.expect(full.categories.count == MenuBarManagerSupport.maxCategories, "the category list is capped")
    }

    private static func storage(_ suite: TestSuite) {
        var layout = MenuBarCategoryLayout()
        layout.addCategory(named: "Dev", id: "dev")
        layout.assign(itemID: "com.docker|#0", to: "dev")
        layout.setSection(.alwaysHidden, for: "com.docker")
        let restored = MenuBarManagerSupport.decodeLayout(MenuBarManagerSupport.encodeLayout(layout))
        suite.expect(restored == layout, "sections and categories survive being saved")
        suite.expect(MenuBarManagerSupport.decodeLayout("") == MenuBarCategoryLayout()
                     && MenuBarManagerSupport.decodeLayout("{not json") == MenuBarCategoryLayout(),
                     "a missing or damaged save starts empty instead of failing")
        let older = #"{"assignments":{"a|#0":"gone","b|#0":"dev"},"categories":[{"id":"dev","name":"Dev"},{"id":"dev","name":"Twin"}]}"#
        let cleaned = MenuBarManagerSupport.decodeLayout(older)
        suite.expect(cleaned.categories == [MenuBarCategory(id: "dev", name: "Dev")]
                     && cleaned.assignments == ["b|#0": "dev"] && cleaned.sections.isEmpty,
                     "a save from before sections existed still loads, cleaned of what points nowhere")

        let remembered = ["com.docker": [MenuBarRememberedItem(key: "com.docker|#0", title: "Docker",
                                                               appName: "Docker Desktop", identifier: nil)]]
        suite.expect(MenuBarManagerSupport.decodeRemembered(MenuBarManagerSupport.encodeRemembered(remembered))
                     == remembered && MenuBarManagerSupport.decodeRemembered("[1,2]").isEmpty,
                     "the icons of hidden apps are remembered across launches")

        suite.expect(MenuBarManagerSupport.rehideChoices.allSatisfy {
            MenuBarManagerSupport.sanitizedRehideSeconds($0) == $0
        } && MenuBarManagerSupport.sanitizedRehideSeconds(7) == MenuBarManagerSupport.defaultRehideSeconds,
                     "the hide delay is one of the offered choices")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.menuBarManagerRehideSeconds] as? Int
                     == MenuBarManagerSupport.defaultRehideSeconds
                     && Defaults.registeredDefaults[DefaultsKey.menuBarManagerEnabled] as? Bool == false,
                     "the manager ships switched off with the default hide delay")

        let backup = SettingsBackupSupport.exportKeys()
        suite.expect([DefaultsKey.menuBarManagerEnabled, DefaultsKey.menuBarManagerShowOnHover,
                      DefaultsKey.menuBarManagerRehideSeconds, DefaultsKey.menuBarManagerClickOpensCategories,
                      DefaultsKey.menuBarManagerCategories].allSatisfy(backup.contains)
                     && !backup.contains(DefaultsKey.menuBarManagerDisallowed)
                     && !backup.contains(DefaultsKey.menuBarManagerRememberedItems),
                     "choices travel in a backup; this Mac's switch record and seen icons do not")
        suite.expect(AppFeature.menuBarManager.enabledKeys == [DefaultsKey.menuBarManagerEnabled]
                     && !AppFeature.menuBarManager.installedByDefault
                     && AppFeature.menuBarManager.settingsDestination == FeatureSettingsDestination(.menuBarManager)
                     && FeatureVisibilitySupport.features(for: .menuBarManager) == [.menuBarManager],
                     "the manager is opt-in and has a Settings page of its own")
        for language in AppLanguage.allCases {
            let strings = FeatureStrings.menuBarManager(language)
            suite.expect(String(format: strings.rehideSecondsFormat, 15).contains("15")
                         && strings.requiresMacOS27.contains("27"),
                         "the delay and the macOS requirement read right in \(language.rawValue)")
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
        suite.expect(MenuBarManagerSupport.bundleID(ofItemKey: "com.docker.docker|#1") == "com.docker.docker",
                     "an icon key names its app")
        suite.expect(MenuBarManagerSupport.displayTitle(title: nil, description: "Wi-Fi, connected, 3 bars",
                                                        appName: "MenuBarAgent") == "Wi-Fi"
                     && MenuBarManagerSupport.displayTitle(title: " ", description: nil, appName: "Docker") == "Docker",
                     "an icon is called by its title, then its description without the live state, then its app")
        suite.expect(MenuBarManagerSupport.systemSymbol(forIdentifier: "com.apple.menuextra.wifi") == "wifi"
                     && MenuBarManagerSupport.systemSymbol(forIdentifier: "Item-0") == nil,
                     "system icons get a symbol of their own")
        suite.expect(MenuBarManagerSupport.canHide(bundleID: "com.docker.docker", ownBundleID: "com.vorssaint.utils")
                     && !MenuBarManagerSupport.canHide(bundleID: "com.vorssaint.utils", ownBundleID: "com.vorssaint.utils")
                     && !MenuBarManagerSupport.canHide(bundleID: "", ownBundleID: nil),
                     "every app but this one and the system can be hidden")
    }
}
