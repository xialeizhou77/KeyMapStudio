import AppKit
import KeyMapCore
import SwiftUI
import UniformTypeIdentifiers

struct SnapshotBackupView: View {
    let appState: AppState

    @State private var showCreateSheet: Bool = false
    @State private var draftSnapshotName: String = ""
    @State private var snapshotPendingRestore: KeyMapSnapshot? = nil

    init(appState: AppState) {
        self.appState = appState
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if appState.snapshots.isEmpty {
                        emptyStateView
                    } else {
                        snapshotListView
                    }
                }
                .padding(20)
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            createSnapshotSheet
        }
        .confirmationDialog(
            "确定恢复快照「\(snapshotPendingRestore?.name ?? "")」吗？",
            isPresented: Binding(
                get: { snapshotPendingRestore != nil },
                set: { presented in
                    if !presented { snapshotPendingRestore = nil }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("恢复此快照", role: .destructive) {
                if let target = snapshotPendingRestore {
                    appState.restoreSnapshot(target)
                }
                snapshotPendingRestore = nil
            }
            Button("取消", role: .cancel) {
                snapshotPendingRestore = nil
            }
        } message: {
            Text("系统快捷键、应用菜单覆盖、HID/组合键映射及开发工具配置将被回滚到该快照状态；部分应用需重启生效。")
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("快照与配置备份")
                    .font(.title3.weight(.semibold))
                Text("保存完整键位配置快照，支持一键回滚与 JSON 导入导出迁移")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                importJSONPanel()
            } label: {
                Label("导入 JSON", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.bordered)

            Button {
                exportCurrentJSONPanel()
            } label: {
                Label("导出 JSON", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)

            Button {
                draftSnapshotName = Self.suggestedName()
                showCreateSheet = true
            } label: {
                Label("立即创建快照", systemImage: "camera.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }

    // MARK: - Snapshot List & Empty State

    private var emptyStateView: some View {
        GroupBox {
            ContentUnavailableView {
                Label("尚无配置快照", systemImage: "clock.arrow.circlepath")
            } description: {
                Text("在批量修改系统、菜单或开发工具快捷键前，建议先创建一份基线快照以便随时回滚。")
            } actions: {
                Button("立即创建快照") {
                    draftSnapshotName = Self.suggestedName()
                    showCreateSheet = true
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, minHeight: 260)
        }
    }

    private var snapshotListView: some View {
        LazyVStack(spacing: 12) {
            ForEach(appState.snapshots) { snapshot in
                snapshotCard(snapshot)
            }
        }
    }

    private func snapshotCard(_ snapshot: KeyMapSnapshot) -> some View {
        let symbolicCount = snapshot.symbolicHotkeys.count
        let menuCount = snapshot.appMenuOverrides.values.reduce(0) { $0 + $1.count }
        let hidCount = snapshot.hidRules.count
        let comboCount = snapshot.comboRules.count
        let devToolCount = snapshot.devToolOverrides.values.reduce(0) { $0 + $1.count }

        return GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "archivebox.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 34, height: 34)
                        .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(snapshot.name)
                            .font(.headline)

                        Text("创建时间：\(Self.formatTimestamp(snapshot.createdAt)) · Schema v\(snapshot.schemaVersion)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Button("导出") {
                            exportSpecificSnapshotPanel(snapshot)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("恢复此快照") {
                            snapshotPendingRestore = snapshot
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        Button("删除", role: .destructive) {
                            appState.deleteSnapshot(snapshot)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                Divider()

                HStack(spacing: 10) {
                    countBadge(title: "系统热键", count: symbolicCount, color: .blue)
                    countBadge(title: "菜单覆盖", count: menuCount, color: .green)
                    countBadge(title: "HID 映射", count: hidCount, color: .orange)
                    countBadge(title: "组合键映射", count: comboCount, color: .orange)
                    countBadge(title: "开发工具", count: devToolCount, color: .purple)
                }
            }
            .padding(6)
        }
    }

    private func countBadge(title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(count)")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(color.opacity(0.10), in: Capsule())
    }

    // MARK: - Create Sheet

    private var createSnapshotSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("创建新配置快照")
                .font(.title3.weight(.semibold))

            Text("将保存当前系统快捷键、所有应用菜单覆盖、HID 规则、组合键映射规则及开发工具快捷键。")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("快照名称", text: $draftSnapshotName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("取消") {
                    showCreateSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Button("创建快照") {
                    appState.createSnapshot(name: draftSnapshotName)
                    showCreateSheet = false
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    // MARK: - File Panels

    private func exportCurrentJSONPanel() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "KeyMapStudio-\(Self.fileTimestamp()).json"
        panel.title = "导出当前键位配置为 JSON"
        if panel.runModal() == .OK, let url = panel.url {
            appState.exportSnapshotJSON(to: url)
        }
    }

    private func exportSpecificSnapshotPanel(_ snapshot: KeyMapSnapshot) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        let safeName = snapshot.name.replacingOccurrences(of: "/", with: "-")
        panel.nameFieldStringValue = "\(safeName).json"
        panel.title = "导出快照「\(snapshot.name)」"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try SnapshotManager().exportJSON(snapshot, to: url)
                appState.showBanner("已导出快照「\(snapshot.name)」到 \(url.lastPathComponent)")
            } catch {
                appState.showBanner("导出快照失败：\(error.localizedDescription)", isError: true)
            }
        }
    }

    private func importJSONPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "导入 KeyMapStudio 快照 JSON"
        if panel.runModal() == .OK, let url = panel.url {
            appState.importSnapshotJSON(from: url)
        }
    }

    // MARK: - Date Formatting

    private static func suggestedName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return "基线快照 \(formatter.string(from: Date()))"
    }

    private static func fileTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    private static func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}
