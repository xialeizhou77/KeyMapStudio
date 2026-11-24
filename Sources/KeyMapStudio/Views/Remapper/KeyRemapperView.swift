import KeyMapCore
import SwiftUI

struct KeyRemapperView: View {
    let appState: AppState

    enum RemapperTab: String, CaseIterable, Identifiable {
        case hid = "硬件单键重映射 (hidutil)"
        case combo = "组合键重映射 (CGEventTap)"
        var id: String { rawValue }
    }

    @State private var selectedTab: RemapperTab = .hid
    @State private var showAddComboSheet: Bool = false

    // Add Combo Sheet State
    @State private var draftComboName: String = ""
    @State private var draftSourceCombo: KeyCombo? = nil
    @State private var draftTargetCombo: KeyCombo? = nil
    @State private var draftTargetAppBundleID: String? = nil

    init(appState: AppState) {
        self.appState = appState
    }

    private var hidSelectableKeys: [KeyDefinition] {
        var seen = Set<UInt64>()
        return KeyCodeCatalog.allKeys.filter { key in
            guard key.hidUsage != 0 else { return false }
            return seen.insert(key.hidUsage).inserted
        }
    }

    private var uniqueRunningApps: [RunningAppInfo] {
        var seen = Set<String>()
        return appState.runningApps.filter { seen.insert($0.bundleID).inserted }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if selectedTab == .hid {
                        hidTabContent
                    } else {
                        comboTabContent
                    }
                }
                .padding(20)
            }
        }
        .sheet(isPresented: $showAddComboSheet) {
            addComboRuleSheet
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("底层改键与映射")
                    .font(.title3.weight(.semibold))
                Text(selectedTab == .hid
                    ? "内核级 HID 硬件单键重映射，无需后台常驻即可即时生效"
                    : "基于 CGEventTap 的全局或分应用组合键映射引擎")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("模式", selection: $selectedTab) {
                ForEach(RemapperTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 420)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }

    // MARK: - Tab 1: HID Remapper

    private var hidTabContent: some View {
        @Bindable var state = appState

        return VStack(alignment: .leading, spacing: 18) {
            // Action & LaunchAgent Control Card
            GroupBox {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("开机自动应用 (LaunchAgent 持久化)", isOn: Binding(
                            get: { appState.isHidLaunchAgentInstalled },
                            set: { appState.setHidLaunchAgent(enabled: $0) }
                        ))
                        .toggleStyle(.switch)

                        Text("将当前 HID 映射写入 ~/Library/LaunchAgents，重启 macOS 后自动生效。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("重置全部 (清空 hidutil)", role: .destructive) {
                        appState.clearHidRules()
                    }
                    .buttonStyle(.bordered)

                    Button {
                        appState.applyHidRules()
                    } label: {
                        Label("立即应用", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(6)
            }

            // Built-in Presets
            VStack(alignment: .leading, spacing: 10) {
                Text("常用预设方案")
                    .font(.headline)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250, maximum: 360), spacing: 12)], spacing: 12) {
                    ForEach(HidRemapRule.builtInPresets) { preset in
                        hidPresetCard(preset)
                    }
                }
            }

            // Custom Rule List
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("自定义单键规则 (\(appState.hidRules.count))")
                        .font(.headline)
                    Spacer()
                    Button {
                        addEmptyHidRule()
                    } label: {
                        Label("添加规则", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                }

                if appState.hidRules.isEmpty {
                    GroupBox {
                        ContentUnavailableView(
                            "暂无硬件改键规则",
                            systemImage: "arrow.left.arrow.right",
                            description: Text("点击上方预设快速添加，或点击「添加规则」自定义任意按键重映射。")
                        )
                        .frame(maxWidth: .infinity, minHeight: 140)
                    }
                } else {
                    VStack(spacing: 8) {
                        ForEach($state.hidRules) { $rule in
                            hidRuleRow(rule: $rule)
                        }
                    }
                }
            }
        }
    }

    private func hidPresetCard(_ preset: HidRemapRule) -> some View {
        let existingIndex = appState.hidRules.firstIndex {
            $0.sourceUsage == preset.sourceUsage && $0.targetUsage == preset.targetUsage
        }
        let isAddedAndEnabled = existingIndex.map { appState.hidRules[$0].isEnabled } ?? false

        return GroupBox {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.name)
                        .font(.subheadline.weight(.semibold))
                    HStack(spacing: 6) {
                        Text(hidKeyLabel(for: preset.sourceUsage))
                            .font(.caption.monospaced())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(hidKeyLabel(for: preset.targetUsage))
                            .font(.caption.monospaced())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.16), in: RoundedRectangle(cornerRadius: 4))
                    }
                }

                Spacer()

                Button(isAddedAndEnabled ? "已启用" : (existingIndex != nil ? "启用" : "添加并应用")) {
                    if let idx = existingIndex {
                        appState.hidRules[idx].isEnabled = true
                    } else {
                        var rule = preset
                        rule.isEnabled = true
                        appState.hidRules.append(rule)
                    }
                    appState.applyHidRules()
                }
                .buttonStyle(.bordered)
                .tint(isAddedAndEnabled ? .green : .accentColor)
                .controlSize(.small)
            }
            .padding(4)
        }
    }

    private func hidRuleRow(rule: Binding<HidRemapRule>) -> some View {
        GroupBox {
            HStack(spacing: 12) {
                Toggle("", isOn: rule.isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)

                TextField("规则名称", text: rule.name)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 170)

                Picker("源按键", selection: rule.sourceUsage) {
                    ForEach(hidSelectableKeys, id: \.hidUsage) { key in
                        Text("\(key.label) (\(key.symbol))").tag(key.hidUsage)
                    }
                }
                .labelsHidden()
                .frame(minWidth: 140)

                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)

                Picker("目标按键", selection: rule.targetUsage) {
                    ForEach(hidSelectableKeys, id: \.hidUsage) { key in
                        Text("\(key.label) (\(key.symbol))").tag(key.hidUsage)
                    }
                }
                .labelsHidden()
                .frame(minWidth: 140)

                Spacer()

                Button(role: .destructive) {
                    let targetID = rule.wrappedValue.id
                    appState.hidRules.removeAll { $0.id == targetID }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("删除此规则")
            }
            .padding(4)
        }
    }

    private func addEmptyHidRule() {
        let capsUsage = KeyCodeCatalog.definition(forVirtualKey: 57)?.hidUsage ?? 0x700000039
        let escUsage = KeyCodeCatalog.definition(forVirtualKey: 53)?.hidUsage ?? 0x700000029
        let newRule = HidRemapRule(
            id: UUID(),
            name: "自定义规则 \(appState.hidRules.count + 1)",
            sourceUsage: capsUsage,
            targetUsage: escUsage,
            isEnabled: true
        )
        appState.hidRules.append(newRule)
    }

    private func hidKeyLabel(for usage: UInt64) -> String {
        if let def = KeyCodeCatalog.definition(forHIDUsage: usage) {
            return def.label
        }
        return String(format: "0x%llX", usage)
    }

    // MARK: - Tab 2: Combo Remapper

    private var comboTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !appState.inputMonitoringGranted || !appState.accessibilityGranted {
                permissionWarningBanner
            }

            // Live Engine Toggle Card
            GroupBox {
                HStack(spacing: 14) {
                    Circle()
                        .fill(appState.isComboRemapRunning ? Color.green : Color.secondary.opacity(0.4))
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(appState.isComboRemapRunning ? "组合键映射引擎运行中 (CGEventTap)" : "组合键映射引擎已停止")
                            .font(.headline)
                        Text("支持跨应用或指定应用将源组合键实时转换为目标组合键；录制快捷键时会自动暂停以防循环触发。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { appState.isComboRemapRunning },
                        set: { appState.toggleComboRemapEngine($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                }
                .padding(6)
            }

            // Rule List Header
            HStack {
                Text("组合键重映射规则 (\(appState.comboRules.count))")
                    .font(.headline)
                Spacer()
                Button {
                    resetDraftComboSheet()
                    showAddComboSheet = true
                } label: {
                    Label("新增组合键映射", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }

            if appState.comboRules.isEmpty {
                GroupBox {
                    ContentUnavailableView(
                        "暂无组合键映射规则",
                        systemImage: "command.square",
                        description: Text("点击「新增组合键映射」可创建如 ⌃H → ⌫ 或仅在特定应用中生效的自定义快捷键转发。")
                    )
                    .frame(maxWidth: .infinity, minHeight: 150)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(appState.comboRules) { rule in
                        comboRuleRow(rule)
                    }
                }
            }
        }
    }

    private var permissionWarningBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("需要权限才能运行 CGEventTap 组合键重映射")
                    .font(.subheadline.weight(.semibold))
                Text("请确保在「系统设置 → 隐私与安全性」中同时开启输入监控与辅助功能权限。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !appState.inputMonitoringGranted {
                Button("请求输入监控") {
                    _ = PermissionManager.requestInputMonitoring()
                    appState.refreshPermissions()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("打开设置") {
                    PermissionManager.openInputMonitoringSettings()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else if !appState.accessibilityGranted {
                Button("打开辅助功能设置") {
                    PermissionManager.openAccessibilitySettings()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            Button("刷新") {
                appState.refreshPermissions()
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
        .padding(12)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.35), lineWidth: 1)
        )
    }

    private func comboRuleRow(_ rule: ComboRemapRule) -> some View {
        let scopeName: String = {
            guard let bundleID = rule.targetAppBundleID, !bundleID.isEmpty else {
                return "全局"
            }
            return appState.runningApps.first { $0.bundleID == bundleID }?.name ?? bundleID
        }()

        return GroupBox {
            HStack(spacing: 12) {
                Toggle("", isOn: Binding(
                    get: { rule.isEnabled },
                    set: { newValue in
                        if let idx = appState.comboRules.firstIndex(where: { $0.id == rule.id }) {
                            appState.comboRules[idx].isEnabled = newValue
                            appState.saveComboRules()
                        }
                    }
                ))
                .labelsHidden()
                .toggleStyle(.switch)

                VStack(alignment: .leading, spacing: 3) {
                    Text(rule.name)
                        .font(.body.weight(.medium))
                    Text("作用域: \(scopeName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                KeyCapBadge(combo: rule.source, size: .compact)

                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                KeyCapBadge(combo: rule.target, size: .compact, highlighted: true)

                Button(role: .destructive) {
                    appState.comboRules.removeAll { $0.id == rule.id }
                    appState.saveComboRules()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("删除规则")
            }
            .padding(4)
        }
    }

    // MARK: - Add Combo Sheet

    private var addComboRuleSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("新增组合键映射")
                .font(.title3.weight(.semibold))

            Form {
                TextField("规则名称 (可选)", text: $draftComboName)

                LabeledContent("源组合键 (触发)") {
                    ShortcutRecorderView(
                        combo: $draftSourceCombo,
                        allowEmpty: false,
                        placeholder: "点击录制源快捷键",
                        onRecordingChanged: { appState.isRecordingShortcut = $0 }
                    )
                    .frame(width: 210)
                }

                LabeledContent("目标组合键 (输出)") {
                    ShortcutRecorderView(
                        combo: $draftTargetCombo,
                        allowEmpty: false,
                        placeholder: "点击录制目标快捷键",
                        onRecordingChanged: { appState.isRecordingShortcut = $0 }
                    )
                    .frame(width: 210)
                }

                Picker("生效应用范围", selection: $draftTargetAppBundleID) {
                    Text("全局 (所有应用)").tag(String?.none)
                    Divider()
                    ForEach(uniqueRunningApps) { app in
                        Text("\(app.name) (\(app.bundleID))").tag(String?.some(app.bundleID))
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("取消") {
                    appState.isRecordingShortcut = false
                    showAddComboSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Button("保存规则") {
                    guard let source = draftSourceCombo, let target = draftTargetCombo else { return }
                    let trimmedName = draftComboName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let finalName = trimmedName.isEmpty ? "\(source.displayString) → \(target.displayString)" : trimmedName
                    let newRule = ComboRemapRule(
                        id: UUID(),
                        name: finalName,
                        source: source,
                        target: target,
                        targetAppBundleID: draftTargetAppBundleID,
                        isEnabled: true
                    )
                    appState.comboRules.append(newRule)
                    appState.saveComboRules()
                    appState.isRecordingShortcut = false
                    showAddComboSheet = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(draftSourceCombo == nil || draftTargetCombo == nil)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 480)
        .onDisappear {
            appState.isRecordingShortcut = false
        }
    }

    private func resetDraftComboSheet() {
        draftComboName = ""
        draftSourceCombo = nil
        draftTargetCombo = nil
        draftTargetAppBundleID = nil
    }
}
