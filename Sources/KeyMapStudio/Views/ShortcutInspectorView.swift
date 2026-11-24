import SwiftUI
import KeyMapCore

struct ShortcutInspectorView: View {
    let appState: AppState

    var body: some View {
        Group {
            if let item = appState.selectedShortcut {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        headerSection(item)
                        Divider()
                        bindingSection(item)
                        conflictSection(item)
                        restartNoticeSection(item)
                        metadataSection(item)
                    }
                    .padding(16)
                }
            } else {
                ContentUnavailableView {
                    Label("选择一个快捷键", systemImage: "command")
                } description: {
                    Text("在左侧列表中选中任意快捷键即可查看详情、修改绑定或处理冲突。")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func headerSection(_ item: ShortcutItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(item.source.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(sourceColor(item.source)))

                if item.isModified {
                    Text("已自定义")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(Capsule().fill(Color.blue.opacity(0.12)))
                }

                Spacer()

                Text(item.isEnabled ? "已启用" : "已禁用")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(item.isEnabled ? .green : .secondary)
            }

            Text(item.title)
                .font(.title3.weight(.semibold))
                .textSelection(.enabled)

            if !item.subtitle.isEmpty {
                Text(item.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            HStack(spacing: 6) {
                Label(item.appName, systemImage: "app")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !item.category.isEmpty {
                    Text("· \(item.category)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func bindingSection(_ item: ShortcutItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("当前按键绑定")
                .font(.subheadline.weight(.semibold))

            HStack {
                KeyCapBadge(combo: item.combo, size: .large, highlighted: item.isModified)
                Spacer()
            }

            if item.isEditable {
                VStack(alignment: .leading, spacing: 8) {
                    Text("录制新快捷键")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ShortcutRecorderView(
                        combo: Binding(
                            get: { item.combo },
                            set: { newCombo in
                                if let newCombo {
                                    appState.updateShortcut(item, newCombo: newCombo)
                                }
                            }
                        ),
                        onRecordingChanged: { recording in
                            appState.isRecordingShortcut = recording
                        }
                    )
                }
            } else {
                Text("此快捷键当前为只读状态，请在对应工具或「底层改键」页面调整。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let defaultCombo = item.defaultCombo {
                HStack {
                    Text("系统/默认绑定：")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    KeyCapBadge(combo: defaultCombo, size: .compact)
                    Spacer()
                }
            }

            HStack(spacing: 10) {
                if supportsEnableToggle(item.source) {
                    Toggle("启用该快捷键", isOn: Binding(
                        get: { item.isEnabled },
                        set: { enabled in
                            appState.toggleShortcut(item, enabled: enabled)
                        }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }

                Spacer()

                if item.isEditable && (item.isModified || item.defaultCombo != nil) {
                    Button("恢复默认") {
                        appState.resetShortcut(item)
                    }
                    .controlSize(.small)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.16), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func conflictSection(_ item: ShortcutItem) -> some View {
        let relatedConflicts = appState.conflicts(for: item)
        if !relatedConflicts.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("检测到 \(relatedConflicts.count) 项键位冲突", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(relatedConflicts.contains(where: { $0.severity == .critical }) ? .red : .orange)

                ForEach(relatedConflicts) { conflict in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(conflict.severity.displayName)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(severityColor(conflict.severity)))

                            Text(conflict.reason)
                                .font(.caption)
                                .foregroundStyle(.primary)
                        }

                        ForEach(conflict.items.filter { $0.id != item.id }) { peer in
                            Button {
                                appState.selectedShortcutID = peer.id
                            } label: {
                                HStack {
                                    Text("• \(peer.appName): \(peer.title)")
                                        .font(.caption)
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "arrow.right.circle")
                                        .font(.caption)
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(severityColor(conflict.severity).opacity(0.08))
                    )
                }

                Button("前往冲突中心处理") {
                    appState.selectedSection = .conflicts
                }
                .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private func restartNoticeSection(_ item: ShortcutItem) -> some View {
        if item.source == .appMenu,
           let bundleID = item.appBundleID,
           bundleID != AppMenuShortcutStore.globalDomain,
           appState.appNeedsRestartBundleID == bundleID {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("需要重启应用以生效")
                        .font(.caption.weight(.semibold))
                    Text("macOS 仅在应用启动时加载新的菜单快捷键。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("立即重启") {
                    appState.restartApp(bundleID: bundleID)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.blue.opacity(0.09))
            )
        }
    }

    private func metadataSection(_ item: ShortcutItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("技术详情")
                .font(.subheadline.weight(.semibold))

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                if let bundleID = item.appBundleID {
                    metaRow("Bundle ID", bundleID)
                }
                if let combo = item.combo {
                    metaRow("虚拟键码", "\(combo.keyCode) (\(combo.keyDisplayName))")
                    metaRow("Canonical", combo.canonicalKey)
                    metaRow("NSUserKey", combo.nsUserKeyEquivalent)
                    metaRow("VS Code", combo.vsCodeString)
                }
                ForEach(item.metadata.keys.sorted(), id: \.self) { key in
                    if let val = item.metadata[key], !val.isEmpty {
                        metaRow(key, val)
                    }
                }
            }
            .font(.caption)
        }
    }

    private func metaRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
            Text(value)
                .textSelection(.enabled)
                .lineLimit(2)
                .gridColumnAlignment(.leading)
        }
    }

    private func supportsEnableToggle(_ source: ShortcutSource) -> Bool {
        switch source {
        case .systemSymbolic, .devTool, .hidRemap, .comboRemap:
            return true
        case .appMenu:
            return false
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

    private func severityColor(_ severity: ConflictSeverity) -> Color {
        switch severity {
        case .critical: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }
}
