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
    @AppStorage(DefaultsKey.menuBarManagerAlwaysHidden) private var alwaysHidden = false
    @AppStorage(DefaultsKey.menuBarManagerClickOpensCategories) private var clickOpensCategories = false
    @State private var newCategoryName = ""
    @State private var spacing: Int?
    @State private var padding: Int?

    private var strings: MenuBarManagerStrings { FeatureStrings.menuBarManager(l10n.language) }

    var body: some View {
        Form {
            generalSection
            if enabled {
                layoutSection
                categoriesSection
            }
            spacingSection
        }
        .formStyle(.grouped)
        .onAppear {
            rehideSeconds = MenuBarManagerSupport.sanitizedRehideSeconds(rehideSeconds)
            spacing = MenuBarItemSpacingPreference.value(forKey: MenuBarManagerSupport.spacingKey)
            padding = MenuBarItemSpacingPreference.value(forKey: MenuBarManagerSupport.paddingKey)
            if enabled { manager.refreshItems() }
        }
    }

    // MARK: Hiding

    private var generalSection: some View {
        Section(strings.title) {
            Toggle(strings.enableLabel, isOn: $enabled)
                .onChange(of: enabled) { _, value in
                    manager.syncWithPreferences()
                    if value { manager.refreshItems() }
                }
            Text(strings.enableCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if enabled {
                if manager.dividerMisplaced {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(strings.misplacedWarning, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                        Button(strings.resetPositions) { manager.resetPositions() }
                            .controlSize(.small)
                    }
                }
                Button(manager.isShowingHidden ? strings.hideNow : strings.showNow) {
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
                Toggle(strings.alwaysHiddenLabel, isOn: $alwaysHidden)
                    .onChange(of: alwaysHidden) { _, _ in
                        manager.syncWithPreferences()
                        manager.refreshItems()
                    }
                Text(strings.alwaysHiddenCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Toggle(strings.clickOpensCategories, isOn: $clickOpensCategories)
            }
        }
    }

    // MARK: Layout

    private var visibleSections: [MenuBarSection] {
        alwaysHidden ? [.visible, .hidden, .alwaysHidden] : [.visible, .hidden]
    }

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
                    if manager.isScanning || manager.isMoving {
                        ProgressView().controlSize(.small)
                    }
                    Button {
                        manager.refreshItems()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help(strings.refresh)
                    .disabled(manager.isMoving)
                }
                if manager.isMoving {
                    Label(strings.moving, systemImage: "hand.draw")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if manager.moveFailed {
                    Label(strings.moveFailed, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if manager.items.isEmpty, !manager.isScanning {
                    Text(strings.noIcons)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                ForEach(visibleSections, id: \.self) { section in
                    sectionGroup(section)
                }
            }
        }
        .disabled(manager.isMoving)
    }

    private func sectionGroup(_ section: MenuBarSection) -> some View {
        let members = manager.items.filter { $0.section == section }
        return VStack(alignment: .leading, spacing: 4) {
            Text(name(of: section))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            ForEach(members) { item in
                itemRow(item)
            }
            if members.isEmpty {
                Text("·")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first, manager.items.contains(where: { $0.id == id }) else { return false }
            manager.move(itemID: id, to: .section(section))
            return true
        }
    }

    private func itemRow(_ item: MenuBarManagedItem) -> some View {
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
            if !manager.layout.categories.isEmpty {
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
            Menu(strings.moveTo) {
                ForEach(visibleSections.filter { $0 != item.section }, id: \.self) { section in
                    Button(name(of: section)) {
                        manager.move(itemID: item.id, to: .section(section))
                    }
                }
            }
            .controlSize(.small)
            .fixedSize()
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .draggable(item.id)
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first, id != item.id,
                  manager.items.contains(where: { $0.id == id }) else { return false }
            manager.move(itemID: id, to: .before(itemID: item.id))
            return true
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

    // MARK: Spacing

    private var spacingSection: some View {
        Section(strings.spacingSection) {
            spacingPicker(strings.spacingLabel, value: $spacing, key: MenuBarManagerSupport.spacingKey)
            spacingPicker(strings.paddingLabel, value: $padding, key: MenuBarManagerSupport.paddingKey)
            Text(strings.spacingCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func spacingPicker(_ title: String, value: Binding<Int?>, key: String) -> some View {
        let steps = Array(stride(from: MenuBarManagerSupport.spacingRange.lowerBound,
                                 through: MenuBarManagerSupport.spacingRange.upperBound, by: 2))
        let selection = Binding<Int>(get: {
            value.wrappedValue ?? -1
        }, set: { chosen in
            let next: Int? = chosen < 0 ? nil : chosen
            value.wrappedValue = next
            MenuBarItemSpacingPreference.setValue(next, forKey: key)
        })
        return Picker(title, selection: selection) {
            Text(strings.spacingDefault).tag(-1)
            ForEach(steps, id: \.self) { points in
                Text(String(points)).tag(points)
            }
            // A value set elsewhere that falls outside the steps still shows.
            if let current = value.wrappedValue, !steps.contains(current) {
                Text(String(current)).tag(current)
            }
        }
    }
}

/// An icon's picture in the editor and the panel: a symbol for the system's
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
