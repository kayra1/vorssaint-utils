// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The popover under the manager's arrow: every menu bar icon under its
/// category. Clicking one opens it as a click in the menu bar would, hidden
/// or not.
struct MenuBarCategoriesPanel: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var manager = MenuBarManagerService.shared

    private var strings: MenuBarManagerStrings { FeatureStrings.menuBarManager(l10n.language) }

    private let columns = [GridItem(.adaptive(minimum: 76, maximum: 96), spacing: 6, alignment: .top)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(strings.categoriesSection)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if manager.isScanning {
                    ProgressView().controlSize(.small)
                }
                Button {
                    manager.closeCategoriesPanel()
                    SettingsRouter.shared.page = .menuBarManager
                    appDelegate()?.openSettingsWindow()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(strings.openSettings)
                .accessibilityLabel(strings.openSettings)
            }
            content
        }
        .padding(12)
        .frame(width: 320)
    }

    @ViewBuilder
    private var content: some View {
        if !permissions.accessibility {
            VStack(alignment: .leading, spacing: 8) {
                Text(strings.layoutPermission)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                PermissionRow(kind: .accessibility)
            }
        } else if manager.items.isEmpty {
            Text(strings.noIcons)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 14)
                .opacity(manager.isScanning ? 0 : 1)
        } else {
            let groups = MenuBarManagerSupport.groups(itemIDs: manager.items.map(\.id), layout: manager.layout)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                        groupView(group, showsTitle: groups.count > 1 || group.categoryID != nil)
                    }
                }
            }
            .frame(maxHeight: 420)
        }
    }

    private func title(of group: MenuBarManagerSupport.CategoryGroup) -> String {
        guard let id = group.categoryID else { return strings.uncategorized }
        return manager.layout.categories.first { $0.id == id }?.name ?? strings.uncategorized
    }

    private func groupView(_ group: MenuBarManagerSupport.CategoryGroup, showsTitle: Bool) -> some View {
        let members = group.itemIDs.compactMap { id in manager.items.first { $0.id == id } }
        return VStack(alignment: .leading, spacing: 5) {
            if showsTitle {
                Text(title(of: group))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                ForEach(members) { item in
                    Button {
                        manager.activate(item)
                    } label: {
                        VStack(spacing: 4) {
                            MenuBarItemGlyph(item: item, size: 24)
                            Text(item.title)
                                .font(.system(size: 10))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 4)
                        .background(Color.primary.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .opacity(item.section == .visible ? 1 : 0.75)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(item.title == item.appName ? item.title : "\(item.title) · \(item.appName)")
                }
            }
        }
    }
}
