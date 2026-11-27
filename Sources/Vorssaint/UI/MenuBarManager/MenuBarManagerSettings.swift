// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct MenuBarManagerSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var manager = MenuBarManagerService.shared
    @AppStorage(DefaultsKey.menuBarManagerEnabled) private var enabled = false
    @State private var newCategoryName = ""

    private var strings: MenuBarManagerStrings { FeatureStrings.menuBarManager(l10n.language) }
    private var supported: Bool { MenuBarManagerService.isSupported }

    var body: some View {
        Form {
            Section {
                Toggle(strings.enableLabel, isOn: supported ? $enabled : .constant(false))
                    .disabled(!supported)
                    .onChange(of: enabled) { _, _ in manager.syncWithPreferences() }
                Text(supported ? strings.enableCaption : strings.requiresMacOS27)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if supported, enabled {
                if MenuBarManagerService.canHideApps, permissions.accessibility {
                    showSection
                }
                categoriesSection
                iconsSection
            }
        }
        .formStyle(.grouped)
        .onAppear {
            if supported, enabled { manager.refreshItems() }
        }
    }

    // MARK: Showing in the menu bar

    private var showSection: some View {
        Section(strings.showSection) {
            Text(strings.showCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if manager.hideFailed {
                Label(strings.hideFailed, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(manager.apps) { app in
                HStack(spacing: 8) {
                    appGlyph(app)
                    Text(app.name)
                        .font(.system(size: 12))
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    if app.canHide {
                        Toggle(strings.showSection, isOn: shownBinding(for: app.bundleID))
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    } else {
                        Text(strings.alwaysShown)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }

    @ViewBuilder
    private func appGlyph(_ app: MenuBarManagedApp) -> some View {
        if let item = manager.items.first(where: { $0.bundleID == app.bundleID }) {
            MenuBarItemGlyph(item: item, size: 18)
        } else {
            Image(systemName: "app.dashed")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)
        }
    }

    private func shownBinding(for bundleID: String) -> Binding<Bool> {
        Binding {
            !manager.layout.isHidden(bundleID)
        } set: { shown in
            manager.setHidden(!shown, for: bundleID)
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

    // MARK: Icons

    @ViewBuilder
    private var iconsSection: some View {
        Section(strings.iconsSection) {
            if !permissions.accessibility {
                Text(strings.permissionNeeded)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                PermissionRow(kind: .accessibility)
            } else {
                HStack(spacing: 8) {
                    Text(strings.iconsCaption)
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
                if manager.items.isEmpty, !manager.isScanning {
                    Text(strings.noIcons)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                ForEach(manager.items) { item in
                    HStack(spacing: 8) {
                        MenuBarItemGlyph(item: item, size: 18)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(item.title)
                                .font(.system(size: 12))
                                .lineLimit(1)
                            if item.title != item.appName {
                                Text(item.appName)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        }
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
                        .disabled(manager.layout.categories.isEmpty)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func categoryBinding(for itemID: String) -> Binding<String> {
        Binding {
            manager.layout.categoryID(for: itemID) ?? ""
        } set: { value in
            manager.updateLayout { $0.assign(itemID: itemID, to: value.isEmpty ? nil : value) }
        }
    }
}

/// An icon's picture in Settings and the dropdown: a symbol for the system's
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
