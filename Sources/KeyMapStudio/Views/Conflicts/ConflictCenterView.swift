import KeyMapCore
import SwiftUI

struct ConflictCenterView: View {
    let appState: AppState

    @State private var selectedSeverity: ConflictSeverity? = nil
    @State private var expandedConflictIDs: Set<String> = []

    init(appState: AppState) {
        self.appState = appState
    }

    private var criticalCount: Int {
        appState.conflicts.filter { $0.severity == .critical }.count
    }

    private var warningCount: Int {
        appState.conflicts.filter { $0.severity == .warning }.count
    }

    private var infoCount: Int {
        appState.conflicts.filter { $0.severity == .info }.count
    }

    private var filteredConflicts: [ConflictItem] {
        guard let selectedSeverity else { return appState.conflicts }
        return appState.conflicts.filter { $0.severity == selectedSeverity }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    summaryCardsRow
                    conflictListSection
                }
                .padding(20)
            }
        }
        .onAppear {
            // Auto-expand top critical conflicts on first view for immediate visibility
            if expandedConflictIDs.isEmpty {
                expandedConflictIDs = Set(appState.conflicts.prefix(3).map(\.id))
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("快捷键冲突中心")
                    .font(.title3.weight(.semibold))
                Text("自动识别跨层覆盖与同作用域热键撞车（不同应用各自独立菜单不会误报）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("严重程度", selection: $selectedSeverity) {
                Text("全部 (\(appState.conflicts.count))").tag(ConflictSeverity?.none)
                Text("高危 (\(criticalCount))").tag(ConflictSeverity?.some(.critical))
                Text("警告 (\(warningCount))").tag(ConflictSeverity?.some(.warning))
                Text("提示 (\(infoCount))").tag(ConflictSeverity?.some(.info))
            }
            .pickerStyle(.segmented)
            .frame(width: 340)

            Button {
                Task { await appState.refreshAll() }
            } label: {
                Label("重新检测", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }

    // MARK: - Summary Cards

    private var summaryCardsRow: some View {
        HStack(spacing: 14) {
            summaryCard(
                severity: .critical,
                title: "高危冲突",
                subtitle: "同作用域直接抢占，必现其一失效",
                count: criticalCount,
                color: .red,
                icon: "exclamationmark.octagon.fill"
            )
            summaryCard(
                severity: .warning,
                title: "跨层警告",
                subtitle: "全局热键遮蔽局部应用或工具快捷键",
                count: warningCount,
                color: .orange,
                icon: "exclamationmark.triangle.fill"
            )
            summaryCard(
                severity: .info,
                title: "上下文提示",
                subtitle: "同一开发工具不同 when 条件复用同键",
                count: infoCount,
                color: .blue,
                icon: "info.circle.fill"
            )
        }
    }

    private func summaryCard(
        severity: ConflictSeverity,
        title: String,
        subtitle: String,
        count: Int,
        color: Color,
        icon: String
    ) -> some View {
        let isSelected = selectedSeverity == severity

        return Button {
            selectedSeverity = isSelected ? nil : severity
        } label: {
            GroupBox {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)
                        .frame(width: 36, height: 36)
                        .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text("\(count)")
                        .font(.title.weight(.bold).monospacedDigit())
                        .foregroundStyle(color)
                }
                .padding(4)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Conflict List

    private var conflictListSection: some View {
        Group {
            if filteredConflicts.isEmpty {
                GroupBox {
                    ContentUnavailableView(
                        appState.conflicts.isEmpty ? "未检测到快捷键冲突" : "当前筛选条件下无冲突",
                        systemImage: "checkmark.shield.fill",
                        description: Text(appState.conflicts.isEmpty
                            ? "当前已扫描的系统、应用菜单、开发工具及改键规则均处于安全无冲突状态。"
                            : "点击顶部筛选器可切换查看其他级别的冲突。")
                    )
                    .frame(maxWidth: .infinity, minHeight: 220)
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(filteredConflicts) { conflict in
                        conflictCard(conflict)
                    }
                }
            }
        }
    }

    private func conflictCard(_ conflict: ConflictItem) -> some View {
        let isExpanded = expandedConflictIDs.contains(conflict.id)
        let color = severityColor(conflict.severity)

        return GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    if isExpanded {
                        expandedConflictIDs.remove(conflict.id)
                    } else {
                        expandedConflictIDs.insert(conflict.id)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 14)

                        KeyCapBadge(combo: conflict.combo, size: .regular, highlighted: true)

                        Text(conflict.severity.displayName)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(color.opacity(0.16), in: Capsule())
                            .foregroundStyle(color)

                        Text(conflict.reason)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        Spacer()

                        Text("\(conflict.items.count) 项参与冲突")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isExpanded {
                    Divider()

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 290), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(conflict.items) { item in
                            conflictItemSideCard(item)
                        }
                    }
                }
            }
            .padding(6)
        }
    }

    private func conflictItemSideCard(_ item: ShortcutItem) -> some View {
        let catColor = sourceColor(item.source)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(item.source.displayName)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(catColor.opacity(0.16), in: Capsule())
                    .foregroundStyle(catColor)

                Text(item.appName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                KeyCapBadge(combo: item.combo, size: .compact)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                if item.isEditable {
                    HStack(spacing: 8) {
                        Text("修改快捷键")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        ShortcutRecorderView(
                            combo: Binding(
                                get: { item.combo },
                                set: { _ in }
                            ),
                            allowEmpty: false,
                            placeholder: "点击重绑",
                            onRecordingChanged: { appState.isRecordingShortcut = $0 },
                            onCommit: { newCombo in
                                if let newCombo {
                                    appState.updateShortcut(item, newCombo: newCombo)
                                }
                            }
                        )
                        .frame(width: 155)
                    }
                }

                HStack(spacing: 8) {
                    Button(item.isEnabled ? "禁用" : "启用") {
                        appState.toggleShortcut(item, enabled: !item.isEnabled)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    if item.isModified || item.defaultCombo != nil {
                        Button("恢复默认") {
                            appState.resetShortcut(item)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Spacer()
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func severityColor(_ severity: ConflictSeverity) -> Color {
        switch severity {
        case .critical: return .red
        case .warning: return .orange
        case .info: return .blue
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
