// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct MenuBarManagerSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var manager = MenuBarManagerService.shared
    @AppStorage(DefaultsKey.menuBarManagerEnabled) private var enabled = false
    @AppStorage(DefaultsKey.menuBarManagerShowOnHover) private var showOnHover = false
    @AppStorage(DefaultsKey.menuBarManagerRehideSeconds)
    private var rehideSeconds = MenuBarManagerSupport.defaultRehideSeconds
    @AppStorage(DefaultsKey.menuBarManagerClickOpensCategories) private var clickOpensCategories = false
    @State private var newCategoryName = ""

    private var strings: MenuBarManagerStrings { FeatureStrings.menuBarManager(l10n.language) }
    private var supported: Bool { MenuBarManagerService.isSupported }

    var body: some View {
        Form {
            generalSection
            if supported, enabled {
                layoutSection
                categoriesSection
            }
        }
        .formStyle(.grouped)
        .onAppear {
            rehideSeconds = MenuBarManagerSupport.sanitizedRehideSeconds(rehideSeconds)
            if supported, enabled { manager.refreshItems() }
        }
    }

    // MARK: Hiding

    private var generalSection: some View {
        Section(strings.title) {
            Toggle(strings.enableLabel, isOn: supported ? $enabled : .constant(false))
                .disabled(!supported)
                .onChange(of: enabled) { _, _ in
                    manager.syncWithPreferences()
                }
            Text(supported ? strings.enableCaption : strings.requiresMacOS27)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if supported, enabled {
                if manager.applyFailed {
                    Label(strings.applyFailed, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button(manager.revealState == .allHidden ? strings.showNow : strings.hideNow) {
                    manager.toggleHidden()
                }
                Toggle(strings.showOnHover, isOn: $showOnHover)
                    .onChange(of: showOnHover) { _, _ in manager.syncWithPreferences() }
                Picker(strings.rehideLabel, selection: $rehideSeconds) {
                    ForEach(MenuBarManagerSupport.rehideChoices, id: \.self) { seconds in
                        Text(seconds == 0 ? strings.rehideNever
                             : String(format: strings.rehideSecondsFormat, seconds))
                            .tag(seconds)
                    }
                }
                Toggle(strings.clickOpensCategories, isOn: $clickOpensCategories)
            }
        }
    }

    // MARK: Layout

    private func name(of section: MenuBarSection) -> String {
        switch section {
        case .visible: return strings.sectionVisible
        case .hidden: return strings.sectionHidden
        case .alwaysHidden: return strings.sectionAlwaysHidden
        }
    }

    @ViewBuilder
    private var layoutSection: some View {
        Section(strings.layoutSection) {
            if !permissions.accessibility {
                Text(strings.layoutPermission)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                PermissionRow(kind: .accessibility)
            } else {
                HStack(spacing: 8) {
                    Text(strings.layoutCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    if manager.isScanning {
                        ProgressView().controlSize(.small)
                    }
                    Button {
                        manager.refreshItems()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help(strings.refresh)
                    .accessibilityLabel(strings.refresh)
                }
                if manager.apps.isEmpty, !manager.isScanning {
                    Text(strings.noIcons)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                ForEach(manager.apps) { app in
                    appRow(app)
                }
            }
        }
    }

    private func appRow(_ app: MenuBarManagedApp) -> some View {
        let appItems = manager.items.filter { $0.bundleID == app.bundleID }
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                if let first = appItems.first {
                    MenuBarItemGlyph(item: first, size: 18)
                }
                Text(app.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Spacer(minLength: 6)
                if app.canHide {
                    Picker(strings.layoutSection, selection: sectionBinding(for: app.bundleID)) {
                        ForEach(MenuBarSection.allCases, id: \.self) { section in
                            Text(name(of: section)).tag(section)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                    .fixedSize()
                } else {
                    Text(strings.alwaysShown)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if !manager.layout.categories.isEmpty {
                ForEach(appItems) { item in
                    HStack(spacing: 8) {
                        Text(item.title)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Picker(strings.categoryLabel, selection: categoryBinding(for: item.id)) {
                            Text(strings.uncategorized).tag("")
                            ForEach(manager.layout.categories) { category in
                                Text(category.name).tag(category.id)
                            }
                        }
                        .labelsHidden()
                        .controlSize(.small)
                        .fixedSize()
                    }
                    .padding(.leading, 26)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func sectionBinding(for bundleID: String) -> Binding<MenuBarSection> {
        Binding {
            manager.layout.section(for: bundleID)
        } set: { section in
            manager.setSection(section, for: bundleID)
        }
    }

    private func categoryBinding(for itemID: String) -> Binding<String> {
        Binding {
            manager.layout.categoryID(for: itemID) ?? ""
        } set: { value in
            manager.updateLayout { $0.assign(itemID: itemID, to: value.isEmpty ? nil : value) }
        }
    }

    // MARK: Categories

    private var categoriesSection: some View {
        Section(strings.categoriesSection) {
            Text(strings.categoriesCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(manager.layout.categories) { category in
                HStack(spacing: 8) {
                    TextField(strings.categoryLabel, text: nameBinding(for: category))
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                    Button {
                        manager.updateLayout { $0.removeCategory(id: category.id) }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help(strings.deleteCategory)
                    .accessibilityLabel(strings.deleteCategory)
                }
            }
            HStack(spacing: 8) {
                TextField(strings.newCategory, text: $newCategoryName)
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addCategory)
                Button(strings.addCategory, action: addCategory)
                    .disabled(MenuBarManagerSupport.sanitizedCategoryName(newCategoryName).isEmpty
                              || manager.layout.categories.count >= MenuBarManagerSupport.maxCategories)
            }
        }
    }

    private func nameBinding(for category: MenuBarCategory) -> Binding<String> {
        Binding {
            manager.layout.categories.first { $0.id == category.id }?.name ?? category.name
        } set: { value in
            manager.updateLayout { $0.renameCategory(id: category.id, to: value) }
        }
    }

    private func addCategory() {
        let name = newCategoryName
        var added = false
        manager.updateLayout { added = $0.addCategory(named: name) }
        if added { newCategoryName = "" }
    }
}

/// An icon's picture in Settings and the panel: a symbol for the system's
/// own icons, the owning app's icon for everything else.
struct MenuBarItemGlyph: View {
    let item: MenuBarManagedItem
    let size: CGFloat

    var body: some View {
        Group {
            if let symbol = item.symbolName {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.7, weight: .medium))
                    .foregroundStyle(.primary)
            } else if let icon = item.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "app.dashed")
                    .font(.system(size: size * 0.7))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
