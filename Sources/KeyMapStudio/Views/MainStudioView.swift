import SwiftUI
import KeyMapCore

struct MainStudioView: View {
    @Bindable var appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(appState: appState)
                .navigationSplitViewColumnWidth(min: 205, ideal: 225, max: 270)
        } detail: {
            VStack(spacing: 0) {
                if let banner = appState.bannerMessage {
                    bannerBar(message: banner, isError: appState.bannerIsError)
                    Divider()
                }

                detailContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .toolbar {
                toolbarContent
            }
        }
        .task {
            if appState.systemShortcuts.isEmpty && !appState.isLoading {
                await appState.refreshAll()
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch appState.selectedSection {
        case .apps:
            HSplitView {
                ShortcutListView(appState: appState, mode: .apps)
                    .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
                ShortcutInspectorView(appState: appState)
                    .frame(minWidth: 300, idealWidth: 340, maxWidth: 420, maxHeight: .infinity)
            }

        case .system:
            HSplitView {
                ShortcutListView(appState: appState, mode: .system)
                    .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
                ShortcutInspectorView(appState: appState)
                    .frame(minWidth: 300, idealWidth: 340, maxWidth: 420, maxHeight: .infinity)
            }

        case .devTools:
            DevToolsView(appState: appState)

        case .keyboard:
            InteractiveKeyboardView(appState: appState)

        case .remapper:
            KeyRemapperView(appState: appState)

        case .conflicts:
            ConflictCenterView(appState: appState)

        case .snapshots:
            SnapshotBackupView(appState: appState)

        case .settings:
            PermissionsSettingsView(appState: appState)
        }
    }

    private func bannerBar(message: String, isError: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: isError ? "xmark.octagon.fill" : "checkmark.circle.fill")
                .foregroundStyle(isError ? .red : .green)

            Text(message)
                .font(.subheadline)
                .lineLimit(2)

            Spacer()

            if let restartBundleID = appState.appNeedsRestartBundleID {
                Button("重启应用以生效") {
                    appState.restartApp(bundleID: restartBundleID)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            Button {
                appState.dismissBanner()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(isError ? Color.red.opacity(0.10) : Color.green.opacity(0.10))
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if appState.isComboRemapRunning {
                Button {
                    appState.selectedSection = .remapper
                } label: {
                    Label("改键引擎运行中", systemImage: "bolt.fill")
                }
                .tint(.green)
                .help("组合键重映射引擎正在运行")
            }

            if !appState.conflicts.isEmpty {
                Button {
                    appState.selectedSection = .conflicts
                } label: {
                    Label("\(appState.conflicts.count) 冲突", systemImage: "exclamationmark.triangle.fill")
                }
                .tint(appState.conflicts.contains(where: { $0.severity == .critical }) ? .red : .orange)
                .help("查看快捷键冲突")
            }

            Button {
                appState.onToggleOverlay?()
            } label: {
                Label("快捷浮窗 (\(appState.overlayHotKey.displayString))", systemImage: "macwindow.on.rectangle")
            }
            .help("打开当前应用快捷键速查浮窗")

            Button {
                Task { await appState.refreshAll() }
            } label: {
                if appState.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
            }
            .disabled(appState.isLoading)
            .help("刷新全部快捷键、权限与冲突状态")
        }
    }
}
