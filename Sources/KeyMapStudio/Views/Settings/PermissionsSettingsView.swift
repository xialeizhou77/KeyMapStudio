import KeyMapCore
import SwiftUI

struct PermissionsSettingsView: View {
    let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    permissionsSection
                    quickOverlayHotkeySection
                    guideAndSafetySection
                }
                .padding(20)
            }
        }
        .onAppear {
            appState.refreshPermissions()
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("权限与设置")
                    .font(.title3.weight(.semibold))
                Text("管理系统隐私授权、全局悬浮快捷键及安全使用说明")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                appState.refreshPermissions()
            } label: {
                Label("刷新权限状态", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }

    // MARK: - Permissions Cards

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("系统隐私权限")
                .font(.headline)

            HStack(alignment: .top, spacing: 14) {
                permissionCard(
                    title: "辅助功能 (Accessibility)",
                    granted: appState.accessibilityGranted,
                    icon: "accessibility",
                    description: "用于通过 AXUIElement 实时读取前台应用菜单树结构及已绑定的应用快捷键。",
                    onRequest: {
                        _ = PermissionManager.promptAccessibility()
                        appState.refreshPermissions()
                    },
                    onOpenSettings: {
                        PermissionManager.openAccessibilitySettings()
                    }
                )

                permissionCard(
                    title: "输入监控 (Input Monitoring)",
                    granted: appState.inputMonitoringGranted,
                    icon: "keyboard.badge.eye",
                    description: "用于 CGEventTap 组合键重映射引擎在底层捕获并转发自定义组合键事件。",
                    onRequest: {
                        _ = PermissionManager.requestInputMonitoring()
                        appState.refreshPermissions()
                    },
                    onOpenSettings: {
                        PermissionManager.openInputMonitoringSettings()
                    }
                )
            }
        }
    }

    private func permissionCard(
        title: String,
        granted: Bool,
        icon: String,
        description: String,
        onRequest: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(granted ? .green : .orange)
                        .frame(width: 34, height: 34)
                        .background((granted ? Color.green : Color.orange).opacity(0.14), in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.headline)
                        HStack(spacing: 5) {
                            Circle()
                                .fill(granted ? Color.green : Color.orange)
                                .frame(width: 7, height: 7)
                            Text(granted ? "已授权" : "未授权")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(granted ? .green : .orange)
                        }
                    }

                    Spacer()
                }

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Button(granted ? "重新校验" : "请求授权") {
                        onRequest()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("打开系统设置") {
                        onOpenSettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(6)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Global Quick Overlay Hotkey

    private var quickOverlayHotkeySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("全局速查浮窗快捷键")
                .font(.headline)

            GroupBox {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("唤起前台应用快捷键速查浮窗 (Quick Overlay)")
                            .font(.subheadline.weight(.medium))
                        Text("在任意应用中按下此全局热键，即可即时弹出当前前台应用的快捷键备忘面板（默认 ⌥⌘K）。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    ShortcutRecorderView(
                        combo: Binding(
                            get: { appState.overlayHotKey },
                            set: { _ in }
                        ),
                        allowEmpty: false,
                        placeholder: "点击设置全局热键",
                        onRecordingChanged: { appState.isRecordingShortcut = $0 },
                        onCommit: { newCombo in
                            if let newCombo {
                                appState.updateOverlayHotKey(newCombo)
                            }
                        }
                    )
                    .frame(width: 190)

                    Button("恢复默认 (⌥⌘K)") {
                        let defaultCombo = KeyCombo(keyCode: 40, modifiers: [.option, .command])
                        appState.updateOverlayHotKey(defaultCombo)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(6)
            }
        }
    }

    // MARK: - Guide & Safety Reset Tips

    private var guideAndSafetySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("使用指南与安全恢复提示")
                .font(.headline)

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    guideRow(
                        icon: "arrow.triangle.2.circlepath",
                        color: .blue,
                        title: "应用菜单快捷键生效说明",
                        detail: "macOS 的应用菜单自定义绑定写入 NSUserKeyEquivalents 后，目标应用通常需要重启才能加载新菜单热键；在「应用与菜单」页面可直接一键重启目标应用。"
                    )

                    Divider()

                    guideRow(
                        icon: "cpu",
                        color: .orange,
                        title: "底层单键重映射 (hidutil) 安全机制",
                        detail: "hidutil 修改仅保存在当前登录会话的内核 HID 映射表中。如果出现按键异常，点击「重置全部」即可秒级还原；仅当开启 LaunchAgent 持久化时才会在重启后自动恢复。"
                    )

                    Divider()

                    guideRow(
                        icon: "shield.lefthalf.filled",
                        color: .red,
                        title: "组合键引擎 (CGEventTap) 紧急停止",
                        detail: "若某条组合键映射导致操作不便，可随时点击菜单栏 KeyMapStudio 图标中的「停止组合键重映射」，或在「底层改键」关闭总开关。录制新快捷键时引擎会自动暂停防干扰。"
                    )

                    Divider()

                    guideRow(
                        icon: "clock.arrow.circlepath",
                        color: .green,
                        title: "修改前建议先创建快照",
                        detail: "前往「快照与备份」创建一份完整基线快照（含系统、菜单覆盖、HID 与开发工具配置），随时支持一键回滚或导出 JSON 迁移。"
                    )
                }
                .padding(8)
            }
        }
    }

    private func guideRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 24, height: 24)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
