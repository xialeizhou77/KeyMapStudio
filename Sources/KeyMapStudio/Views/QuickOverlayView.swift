import SwiftUI
import AppKit
import KeyMapCore

struct QuickOverlayView: View {
    enum OverlayScope: String, CaseIterable, Identifiable {
        case currentApp = "当前应用"
        case all = "全部"
        case systemAndTools = "系统与工具"

        var id: String { rawValue }
    }

    let appState: AppState
    let onClose: () -> Void

    @State private var query: String = ""
    @State private var selectedScope: OverlayScope = .currentApp
    @State private var modifierFilter: KeyModifiers = []
    @FocusState private var isSearchFocused: Bool

    private let modifierOptions: [(KeyModifiers, String)] = [
        (.control, "⌃"),
        (.option, "⌥"),
        (.shift, "⇧"),
        (.command, "⌘")
    ]

    var body: some View {
        VStack(spacing: 0) {
            searchHeader
            Divider()
            scopeBar
            Divider()
            resultsList
            Divider()
            footerBar
        }
        .frame(width: 740, height: 520)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.14), lineWidth: 1)
        )
        .onAppear {
            selectedScope = appState.overlayTargetApp == nil ? .all : .currentApp
            isSearchFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            selectedScope = appState.overlayTargetApp == nil ? .all : .currentApp
            DispatchQueue.main.async {
                isSearchFocused = true
            }
        }
        .onExitCommand {
            onClose()
        }
    }

    private var searchHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("搜索当前应用、系统或开发工具快捷键…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 17))
                .focused($isSearchFocused)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if let target = appState.overlayTargetApp {
                HStack(spacing: 6) {
                    appIconView(bundleID: target.bundleID)
                    Text(target.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.accentColor.opacity(0.14))
                )
            } else {
                Text("全局视图")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.secondary.opacity(0.12)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var scopeBar: some View {
        HStack(spacing: 10) {
            Picker("范围", selection: $selectedScope) {
                ForEach(OverlayScope.allCases) { scope in
                    Text(scope.rawValue).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 280)

            Spacer()

            HStack(spacing: 4) {
                ForEach(modifierOptions, id: \.1) { mod, symbol in
                    let active = modifierFilter.contains(mod)
                    Button {
                        if active {
                            modifierFilter.remove(mod)
                        } else {
                            modifierFilter.insert(mod)
                        }
                    } label: {
                        Text(symbol)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .frame(width: 26, height: 22)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(active ? Color.accentColor : Color(nsColor: .controlBackgroundColor).opacity(0.75))
                            )
                            .foregroundStyle(active ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var resultsList: some View {
        if appState.isScanningApp && selectedScope == .currentApp && appState.overlayShortcuts.isEmpty {
            VStack(spacing: 10) {
                ProgressView()
                Text("正在扫描 \(appState.overlayTargetApp?.name ?? "应用") 菜单…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !appState.accessibilityGranted && selectedScope == .currentApp && appState.overlayShortcuts.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "hand.raised.circle")
                    .font(.system(size: 32))
                    .foregroundStyle(.orange)
                Text("尚未开启「辅助功能」权限，无法实时读取应用菜单")
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 10) {
                    Button("打开系统设置授权") {
                        _ = PermissionManager.promptAccessibility()
                        PermissionManager.openAccessibilitySettings()
                        onClose()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("查看全局快捷键") {
                        selectedScope = .systemAndTools
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filteredResults.isEmpty {
            ContentUnavailableView {
                Label("无匹配快捷键", systemImage: "keyboard")
            } description: {
                Text("尝试修改搜索词、切换范围或清除修饰键筛选。")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filteredResults) { item in
                        overlayRow(item)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
        }
    }

    private func overlayRow(_ item: ShortcutItem) -> some View {
        Button {
            jumpToStudio(item)
        } label: {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(sourceColor(item.source))
                    .frame(width: 3, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(item.appName)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(sourceColor(item.source))
                        if !item.subtitle.isEmpty {
                            Text("· \(item.subtitle)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                KeyCapBadge(combo: item.combo, size: .compact)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.001))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var footerBar: some View {
        HStack {
            Text("共 \(filteredResults.count) 条快捷键 · 点击条目在主窗口中编辑")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button("打开主窗口") {
                openMainWindow()
                onClose()
            }
            .buttonStyle(.plain)
            .font(.caption.weight(.medium))
            .foregroundStyle(Color.accentColor)

            Text("Esc 关闭")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.leading, 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func appIconView(bundleID: String) -> some View {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 16, height: 16)
        } else {
            Image(systemName: "app.fill")
                .font(.system(size: 12))
        }
    }

    private var sourceItemsForScope: [ShortcutItem] {
        switch selectedScope {
        case .currentApp:
            var items = appState.overlayShortcuts
            if let bid = appState.overlayTargetApp?.bundleID {
                let matchingToolIDs = Set(
                    appState.devToolInfos
                        .filter { $0.bundleID == bid }
                        .map(\.id)
                )
                if !matchingToolIDs.isEmpty {
                    let toolItems = appState.devToolShortcuts.filter {
                        guard let tid = $0.metadata["toolID"] else { return false }
                        return matchingToolIDs.contains(tid)
                    }
                    items.append(contentsOf: toolItems)
                }
            }
            return items

        case .systemAndTools:
            return appState.systemShortcuts + appState.devToolShortcuts

        case .all:
            var seen = Set<String>()
            var combined: [ShortcutItem] = []
            for item in appState.overlayShortcuts + appState.allShortcuts {
                if seen.insert(item.id).inserted {
                    combined.append(item)
                }
            }
            return combined
        }
    }

    private var filteredResults: [ShortcutItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let modMask = modifierFilter.intersection(.standardMask)

        return sourceItemsForScope.filter { item in
            if item.combo == nil && trimmed.isEmpty {
                return false
            }

            if !modMask.isEmpty {
                guard let combo = item.combo,
                      combo.modifiers.intersection(modMask) == modMask else {
                    return false
                }
            }

            if trimmed.isEmpty {
                return true
            }

            let text = [
                item.title,
                item.subtitle,
                item.category,
                item.appName,
                item.combo?.displayString ?? "",
                item.combo?.vsCodeString ?? ""
            ].joined(separator: " ").lowercased()

            return text.contains(trimmed)
        }
    }

    private func jumpToStudio(_ item: ShortcutItem) {
        switch item.source {
        case .systemSymbolic:
            appState.selectedSection = .system
        case .appMenu:
            appState.selectedSection = .apps
            if let bid = item.appBundleID {
                if bid == appState.overlayTargetApp?.bundleID, !appState.overlayShortcuts.isEmpty {
                    appState.selectedAppBundleID = bid
                    appState.appMenuShortcuts = appState.overlayShortcuts
                } else if let running = appState.runningApps.first(where: { $0.bundleID == bid }) {
                    Task { await appState.selectAndScanApp(running) }
                }
            }
        case .devTool:
            appState.selectedSection = .devTools
        case .hidRemap, .comboRemap:
            appState.selectedSection = .remapper
        }
        appState.selectedShortcutID = item.id
        openMainWindow()
        onClose()
    }

    private func openMainWindow() {
        if let handler = appState.onOpenMainWindow {
            handler()
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where !(window is NSPanel) && window.canBecomeKey {
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func sourceColor(_ source: ShortcutSource) -> Color {
        switch source {
        case .systemSymbolic: return .blue
        case .appMenu: return .green
        case .devTool: return .purple
        case .hidRemap, .comboRemap: return .orange
        }
    }
}
