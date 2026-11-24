import SwiftUI
import KeyMapCore

struct SidebarView: View {
    @Bindable var appState: AppState

    private let browsingSections: [SidebarSection] = [.apps, .system, .devTools]
    private let visualSections: [SidebarSection] = [.keyboard, .remapper]
    private let maintenanceSections: [SidebarSection] = [.conflicts, .snapshots, .settings]

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $appState.selectedSection) {
                Section("快捷键浏览") {
                    ForEach(browsingSections) { section in
                        sidebarRow(section)
                            .tag(section)
                    }
                }

                Section("可视化与映射") {
                    ForEach(visualSections) { section in
                        sidebarRow(section)
                            .tag(section)
                    }
                }

                Section("诊断与维护") {
                    ForEach(maintenanceSections) { section in
                        sidebarRow(section)
                            .tag(section)
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            sidebarFooter
        }
        .navigationTitle("KeyMapStudio")
    }

    @ViewBuilder
    private func sidebarRow(_ section: SidebarSection) -> some View {
        HStack(spacing: 8) {
            Label(section.title, systemImage: section.systemImage)
                .lineLimit(1)

            Spacer()

            switch section {
            case .conflicts:
                if !appState.conflicts.isEmpty {
                    let hasCritical = appState.conflicts.contains(where: { $0.severity == .critical })
                    Text("\(appState.conflicts.count)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(
                            Capsule()
                                .fill(hasCritical ? Color.red : Color.orange)
                        )
                }

            case .remapper:
                if appState.isComboRemapRunning {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                        .help("组合键引擎运行中")
                }

            case .settings:
                if !appState.accessibilityGranted || !appState.inputMonitoringGranted {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                        .help("部分系统权限尚未开启")
                }

            default:
                EmptyView()
            }
        }
    }

    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                statusDot(active: appState.accessibilityGranted, label: "辅助功能")
                statusDot(active: appState.inputMonitoringGranted, label: "输入监控")
            }

            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("浮窗 \(appState.overlayHotKey.displayString)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    appState.onToggleOverlay?()
                } label: {
                    Text("呼出")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func statusDot(active: Bool, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(active ? Color.green : Color.orange)
                .frame(width: 6.5, height: 6.5)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}
