import SwiftUI
import AppKit
import KeyMapCore

struct ShortcutListView: View {
    enum Mode {
        case apps
        case system
    }

    @Bindable var appState: AppState
    let mode: Mode

    @State private var selectedCategory: String = "全部"
    @State private var showAddMenuSheet: Bool = false

    private var showGlobalOverridesOnly: Bool {
        appState.selectedAppBundleID == AppMenuShortcutStore.globalDomain
    }

    private let modifierOptions: [(KeyModifiers, String)] = [
        (.control, "⌃"),
        (.option, "⌥"),
        (.shift, "⇧"),
        (.command, "⌘")
    ]

    var body: some View {
        VStack(spacing: 0) {
            headerControls
            Divider()

            if mode == .apps && !appState.accessibilityGranted && !showGlobalOverridesOnly {
                accessibilityPromptBanner
                Divider()
            }

            if mode == .apps && appState.isScanningApp {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("正在扫描应用菜单快捷键…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredShortcuts.isEmpty {
                ContentUnavailableView {
                    Label("没有匹配的快捷键", systemImage: "magnifyingglass")
                } description: {
                    Text(emptyStateDescription)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredShortcuts, selection: $appState.selectedShortcutID) { item in
                    shortcutRow(item)
                        .tag(item.id)
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $showAddMenuSheet) {
            AddAppMenuShortcutSheet(appState: appState)
        }
        .onChange(of: appState.selectedAppBundleID) { _, newValue in
            guard mode == .apps,
                  let newValue,
                  newValue != AppMenuShortcutStore.globalDomain,
                  !appState.isScanningApp,
                  let app = appState.runningApps.first(where: { $0.bundleID == newValue }),
                  appState.appMenuShortcuts.first?.appBundleID != newValue else {
                return
            }
            Task { await appState.selectAndScanApp(app) }
        }
    }

    @ViewBuilder
    private var headerControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            if mode == .apps {
                HStack(spacing: 10) {
                    Picker("目标应用", selection: appSelectionBinding) {
                        Text("全局覆盖 (NSGlobalDomain)").tag(AppMenuShortcutStore.globalDomain)
                        Divider()
                        ForEach(appState.runningApps) { app in
                            HStack {
                                Text(app.name)
                            }
                            .tag(app.bundleID)
                        }
                    }
                    .frame(maxWidth: 320)

                    Button {
                        if showGlobalOverridesOnly {
                            Task { await appState.refreshAll() }
                        } else if let app = currentSelectedApp {
                            Task { await appState.selectAndScanApp(app) }
                        }
                    } label: {
                        Label("重新扫描", systemImage: "arrow.clockwise")
                    }
                    .disabled(appState.isScanningApp)

                    Spacer()

                    Button {
                        showAddMenuSheet = true
                    } label: {
                        Label("新增菜单快捷键", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(systemCategories, id: \.self) { category in
                            Button {
                                selectedCategory = category
                            } label: {
                                Text(category)
                                    .font(.system(size: 12, weight: selectedCategory == category ? .semibold : .regular))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(selectedCategory == category
                                                  ? Color.accentColor.opacity(0.18)
                                                  : Color(nsColor: .controlBackgroundColor))
                                    )
                                    .foregroundStyle(selectedCategory == category ? Color.accentColor : Color.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(
                        mode == .apps ? "搜索菜单命令或快捷键…" : "搜索系统快捷键…",
                        text: $appState.searchQuery
                    )
                    .textFieldStyle(.plain)

                    if !appState.searchQuery.isEmpty {
                        Button {
                            appState.searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.22), lineWidth: 1)
                )

                HStack(spacing: 4) {
                    ForEach(modifierOptions, id: \.1) { mod, symbol in
                        let isActive = appState.selectedModifierFilter.contains(mod)
                        Button {
                            if isActive {
                                appState.selectedModifierFilter.remove(mod)
                            } else {
                                appState.selectedModifierFilter.insert(mod)
                            }
                        } label: {
                            Text(symbol)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .frame(width: 26, height: 24)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(isActive ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                                )
                                .foregroundStyle(isActive ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }

                    if !appState.selectedModifierFilter.isEmpty {
                        Button("重置") {
                            appState.selectedModifierFilter = []
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var accessibilityPromptBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.raised.circle.fill")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("需要「辅助功能」权限以扫描应用菜单")
                    .font(.subheadline.weight(.semibold))
                Text("授权后可自动读取任意运行中应用的菜单栏及其快捷键。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("去授权") {
                _ = PermissionManager.promptAccessibility()
                PermissionManager.openAccessibilitySettings()
                appState.refreshPermissions()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button("刷新") {
                appState.refreshPermissions()
                if appState.accessibilityGranted, let app = currentSelectedApp {
                    Task { await appState.selectAndScanApp(app) }
                }
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.08))
    }

    private func shortcutRow(_ item: ShortcutItem) -> some View {
        let itemConflicts = appState.conflicts(for: item)
        return HStack(spacing: 10) {
            Circle()
                .fill(item.isEnabled ? Color.green : Color.secondary.opacity(0.35))
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(item.isEnabled ? .primary : .secondary)
                        .lineLimit(1)

                    if item.isModified {
                        badgeTag("已修改", color: .blue)
                    }

                    if !itemConflicts.isEmpty {
                        let critical = itemConflicts.contains(where: { $0.severity == .critical })
                        badgeTag("冲突", color: critical ? .red : .orange)
                    }
                }

                HStack(spacing: 6) {
                    Text(item.subtitle.isEmpty ? item.category : item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if mode == .system && !item.category.isEmpty {
                        Text("· \(item.category)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            KeyCapBadge(combo: item.combo, size: .compact, highlighted: item.isModified)
        }
        .padding(.vertical, 3)
    }

    private func badgeTag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(
                Capsule().fill(color.opacity(0.14))
            )
    }

    private var appSelectionBinding: Binding<String> {
        Binding(
            get: {
                appState.selectedAppBundleID ?? appState.runningApps.first?.bundleID ?? AppMenuShortcutStore.globalDomain
            },
            set: { newValue in
                if newValue == AppMenuShortcutStore.globalDomain {
                    appState.selectedAppBundleID = AppMenuShortcutStore.globalDomain
                } else if let app = appState.runningApps.first(where: { $0.bundleID == newValue }) {
                    Task { await appState.selectAndScanApp(app) }
                }
            }
        )
    }

    private var currentSelectedApp: RunningAppInfo? {
        guard let bid = appState.selectedAppBundleID else { return nil }
        return appState.runningApps.first(where: { $0.bundleID == bid })
    }

    private var systemCategories: [String] {
        var seen = Set<String>()
        var result = ["全部"]
        for item in appState.systemShortcuts {
            if !item.category.isEmpty && seen.insert(item.category).inserted {
                result.append(item.category)
            }
        }
        return result
    }

    private var baseItems: [ShortcutItem] {
        switch mode {
        case .system:
            if selectedCategory == "全部" {
                return appState.systemShortcuts
            }
            return appState.systemShortcuts.filter { $0.category == selectedCategory }

        case .apps:
            if showGlobalOverridesOnly {
                return appState.customAppOverrides.filter { $0.appBundleID == AppMenuShortcutStore.globalDomain }
            }
            guard let bid = appState.selectedAppBundleID else {
                return appState.customAppOverrides
            }
            var items = appState.appMenuShortcuts
            let extraOverrides = appState.customAppOverrides.filter { overrideItem in
                guard overrideItem.appBundleID == bid else { return false }
                return !items.contains(where: { existing in
                    existing.metadata["menuPath"] == overrideItem.metadata["menuPath"]
                        || existing.metadata["menuTitle"] == overrideItem.metadata["menuTitle"]
                        || existing.title == overrideItem.title
                })
            }
            items.append(contentsOf: extraOverrides)
            return items
        }
    }

    private var filteredShortcuts: [ShortcutItem] {
        let query = appState.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let modFilter = appState.selectedModifierFilter.intersection(.standardMask)

        return baseItems.filter { item in
            if !modFilter.isEmpty {
                guard let combo = item.combo,
                      combo.modifiers.intersection(modFilter) == modFilter else {
                    return false
                }
            }

            if query.isEmpty {
                return true
            }

            let haystack = [
                item.title,
                item.subtitle,
                item.category,
                item.appName,
                item.combo?.displayString ?? "",
                item.combo?.vsCodeString ?? ""
            ].joined(separator: " ").lowercased()

            return haystack.contains(query)
        }
    }

    private var emptyStateDescription: String {
        if mode == .apps && !appState.accessibilityGranted && !showGlobalOverridesOnly {
            return "请先授予辅助功能权限，或切换到「全局覆盖」查看自定义菜单快捷键。"
        }
        return "尝试更换搜索关键词或清除修饰键过滤条件。"
    }
}

private struct AddAppMenuShortcutSheet: View {
    let appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDomain: String = AppMenuShortcutStore.globalDomain
    @State private var menuPathInput: String = ""
    @State private var combo: KeyCombo? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("新增应用菜单快捷键")
                .font(.headline)

            Form {
                Picker("目标应用", selection: $selectedDomain) {
                    Text("全局所有应用 (NSGlobalDomain)").tag(AppMenuShortcutStore.globalDomain)
                    Divider()
                    ForEach(appState.runningApps) { app in
                        Text(app.name).tag(app.bundleID)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    TextField("菜单标题或路径（如：导出… 或 File->Export As…）", text: $menuPathInput)
                    Text("多级菜单可使用 -> 分隔，例如：文件->导出为 PDF…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("快捷键")
                    Spacer()
                    ShortcutRecorderView(
                        combo: $combo,
                        onRecordingChanged: { recording in
                            appState.isRecordingShortcut = recording
                        }
                    )
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("取消") {
                    dismiss()
                }
                Button("添加") {
                    guard let combo else { return }
                    let components = menuPathInput
                        .components(separatedBy: "->")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    let formattedMenu = AppMenuShortcutStore.formatMenuPath(components)
                    let appName = appState.runningApps.first(where: { $0.bundleID == selectedDomain })?.name ?? "全局应用"
                    appState.addAppMenuShortcut(
                        bundleID: selectedDomain,
                        appName: appName,
                        menuTitle: formattedMenu,
                        combo: combo
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(menuPathInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || combo == nil)
            }
        }
        .padding(20)
        .frame(width: 460)
        .onAppear {
            if let bid = appState.selectedAppBundleID {
                selectedDomain = bid
            }
        }
    }
}
