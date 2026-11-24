import Foundation
import AppKit
import Observation
import KeyMapCore

enum SidebarSection: String, CaseIterable, Identifiable {
    case apps, system, devTools, keyboard, remapper, conflicts, snapshots, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apps: return "应用与菜单"
        case .system: return "系统快捷键"
        case .devTools: return "开发工具"
        case .keyboard: return "交互式键盘"
        case .remapper: return "底层改键"
        case .conflicts: return "冲突中心"
        case .snapshots: return "快照与备份"
        case .settings: return "权限与设置"
        }
    }

    var systemImage: String {
        switch self {
        case .apps: return "macwindow"
        case .system: return "gearshape.2"
        case .devTools: return "hammer"
        case .keyboard: return "keyboard"
        case .remapper: return "arrow.left.arrow.right.square"
        case .conflicts: return "exclamationmark.triangle"
        case .snapshots: return "clock.arrow.circlepath"
        case .settings: return "lock.shield"
        }
    }
}

@MainActor
@Observable
final class AppState {
    // MARK: - Navigation & Filters
    var selectedSection: SidebarSection = .apps
    var searchQuery: String = ""
    var selectedModifierFilter: KeyModifiers = []
    var selectedShortcutID: String?

    // MARK: - Shortcut Data Sources
    var systemShortcuts: [ShortcutItem] = []
    var appMenuShortcuts: [ShortcutItem] = []
    var customAppOverrides: [ShortcutItem] = []
    var devToolShortcuts: [ShortcutItem] = []
    var hidRules: [HidRemapRule] = []
    var comboRules: [ComboRemapRule] = []

    var allShortcuts: [ShortcutItem] {
        var combined: [ShortcutItem] = []
        combined.reserveCapacity(
            systemShortcuts.count + appMenuShortcuts.count + customAppOverrides.count + devToolShortcuts.count + hidRules.count + comboRules.count
        )
        combined.append(contentsOf: systemShortcuts)
        combined.append(contentsOf: appMenuShortcuts)

        for overrideItem in customAppOverrides {
            let alreadyInAppMenus = appMenuShortcuts.contains { existing in
                if existing.id == overrideItem.id { return true }
                guard existing.appBundleID == overrideItem.appBundleID else { return false }
                if let existingPath = existing.metadata["menuPath"],
                   let overridePath = overrideItem.metadata["menuPath"],
                   existingPath == overridePath {
                    return true
                }
                if let existingTitle = existing.metadata["menuTitle"],
                   let overrideTitle = overrideItem.metadata["menuTitle"],
                   existingTitle == overrideTitle {
                    return true
                }
                return existing.title == overrideItem.title
            }
            if !alreadyInAppMenus {
                combined.append(overrideItem)
            }
        }

        combined.append(contentsOf: devToolShortcuts)
        combined.append(contentsOf: hidRuleShortcutItems)
        combined.append(contentsOf: comboRuleShortcutItems)
        return combined
    }

    var selectedShortcut: ShortcutItem? {
        guard let selectedShortcutID else { return nil }
        return allShortcuts.first(where: { $0.id == selectedShortcutID })
            ?? overlayShortcuts.first(where: { $0.id == selectedShortcutID })
    }

    // MARK: - App & Overlay State
    var runningApps: [RunningAppInfo] = []
    var selectedAppBundleID: String?
    var overlayTargetApp: RunningAppInfo?
    var overlayShortcuts: [ShortcutItem] = []

    // MARK: - Analysis & Metadata
    var conflicts: [ConflictItem] = []
    var devToolInfos: [DevToolInfo] = []
    var snapshots: [KeyMapSnapshot] = []

    // MARK: - Permissions & Engine Status
    var accessibilityGranted: Bool = false
    var inputMonitoringGranted: Bool = false
    var isComboRemapRunning: Bool = false
    var isHidLaunchAgentInstalled: Bool = false
    var isRecordingShortcut: Bool = false {
        didSet {
            comboRemapEngine.isPausedForRecording = isRecordingShortcut
        }
    }

    var overlayHotKey: KeyCombo = AppState.loadSavedOverlayHotKey()

    // MARK: - UI Feedback
    var bannerMessage: String?
    var bannerIsError: Bool = false
    var appNeedsRestartBundleID: String?
    var isLoading: Bool = false
    var isScanningApp: Bool = false

    // MARK: - Hooks wired by AppDelegate
    var onOverlayHotKeyChanged: ((KeyCombo) -> Void)?
    var onToggleOverlay: (() -> Void)?
    var onOpenMainWindow: (() -> Void)?

    // MARK: - Core Services
    private let symbolicStore = SymbolicHotkeyStore()
    private let axScanner = AXMenuScanner()
    private let appMenuStore = AppMenuShortcutStore()
    private let hidManager = HidRemapManager()
    private let comboRemapEngine = ComboRemapEngine()
    private let devToolRegistry = DevToolRegistry()
    private let snapshotManager = SnapshotManager()

    private var bannerDismissTask: Task<Void, Never>?
    private var lastUpdateRecord: (id: String, combo: KeyCombo, date: Date)?
    private static let overlayHotKeyDefaultsKey = "KeyMapStudio.overlayHotKey"

    init() {}

    // MARK: - Refresh & Scanning

    func refreshAll() async {
        isLoading = true
        defer { isLoading = false }

        refreshPermissions()

        systemShortcuts = symbolicStore.loadShortcuts()
        customAppOverrides = appMenuStore.loadOverrideShortcutItems()
        runningApps = axScanner.listRunningApps()
        devToolInfos = devToolRegistry.detectAll()
        devToolShortcuts = devToolRegistry.loadAllShortcuts()
        hidRules = hidManager.loadRules()
        comboRules = comboRemapEngine.loadRules()
        isComboRemapRunning = comboRemapEngine.isRunning
        isHidLaunchAgentInstalled = hidManager.isLaunchAgentInstalled()
        snapshots = snapshotManager.listSnapshots()

        if selectedAppBundleID == nil {
            let ownBundleID = Bundle.main.bundleIdentifier
            if let preferred = runningApps.first(where: { $0.bundleID != ownBundleID }) ?? runningApps.first {
                selectedAppBundleID = preferred.bundleID
            }
        }

        if let bundleID = selectedAppBundleID,
           let targetApp = runningApps.first(where: { $0.bundleID == bundleID }) {
            await selectAndScanApp(targetApp)
        } else {
            recomputeConflicts()
        }
    }

    func refreshPermissions() {
        accessibilityGranted = PermissionManager.isAccessibilityTrusted()
        inputMonitoringGranted = PermissionManager.isInputMonitoringGranted()
    }

    func selectAndScanApp(_ app: RunningAppInfo) async {
        selectedAppBundleID = app.bundleID
        isScanningApp = true
        defer { isScanningApp = false }

        let overrides = appMenuStore.loadOverrides(forDomain: app.bundleID)
        let scanned = await axScanner.scanMenuShortcuts(for: app, overrides: overrides)
        if selectedAppBundleID == app.bundleID {
            appMenuShortcuts = scanned
        }
        recomputeConflicts()
    }

    func scanFrontmostAppForOverlay(_ app: RunningAppInfo?) async {
        overlayTargetApp = app
        guard let app else {
            overlayShortcuts = []
            return
        }

        isScanningApp = true
        defer { isScanningApp = false }

        let overrides = appMenuStore.loadOverrides(forDomain: app.bundleID)
        let scanned = await axScanner.scanMenuShortcuts(for: app, overrides: overrides)
        if overlayTargetApp?.bundleID == app.bundleID {
            overlayShortcuts = scanned
        }
    }

    // MARK: - Shortcut Editing

    func updateShortcut(_ item: ShortcutItem, newCombo: KeyCombo) {
        let now = Date()
        if let last = lastUpdateRecord,
           last.id == item.id,
           last.combo == newCombo,
           now.timeIntervalSince(last.date) < 0.15 {
            return
        }
        lastUpdateRecord = (item.id, newCombo, now)

        do {
            switch item.source {
            case .systemSymbolic:
                let sid = symbolicID(for: item)
                try symbolicStore.updateHotkey(id: sid, combo: newCombo, enabled: item.isEnabled)
                systemShortcuts = symbolicStore.loadShortcuts()
                showBanner("已更新系统快捷键「\(item.title)」为 \(newCombo.displayString)")

            case .appMenu:
                let domain = item.appBundleID ?? AppMenuShortcutStore.globalDomain
                let menuKey = item.metadata["menuPath"] ?? item.metadata["menuTitle"] ?? item.title
                try appMenuStore.setOverride(
                    domain: domain,
                    appName: item.appName,
                    menuTitleOrPath: menuKey,
                    combo: newCombo
                )
                customAppOverrides = appMenuStore.loadOverrideShortcutItems()
                if domain != AppMenuShortcutStore.globalDomain {
                    appNeedsRestartBundleID = domain
                    if selectedAppBundleID == domain,
                       let app = runningApps.first(where: { $0.bundleID == domain }) {
                        Task { await selectAndScanApp(app) }
                    }
                    showBanner("已更新「\(item.title)」为 \(newCombo.displayString)，重启 \(item.appName) 后生效")
                } else {
                    showBanner("已更新全局菜单快捷键「\(item.title)」为 \(newCombo.displayString)")
                }

            case .devTool:
                guard let toolID = item.metadata["toolID"],
                      let adapter = devToolRegistry.adapter(forToolID: toolID) else {
                    showBanner("未找到开发工具适配器，无法修改", isError: true)
                    return
                }
                guard adapter.supportsWrite else {
                    showBanner("\(item.appName) 暂不支持直接写入快捷键，请在原应用内修改", isError: true)
                    return
                }
                let command = item.metadata["command"] ?? item.title
                let when = item.metadata["when"]
                try adapter.upsertShortcut(
                    command: command,
                    combo: newCombo,
                    when: when,
                    originalCommand: command
                )
                devToolInfos = devToolRegistry.detectAll()
                devToolShortcuts = devToolRegistry.loadAllShortcuts()
                showBanner("已更新 \(item.appName)「\(command)」为 \(newCombo.displayString)")

            case .comboRemap:
                if let ruleIDString = item.metadata["ruleID"],
                   let ruleUUID = UUID(uuidString: ruleIDString),
                   let index = comboRules.firstIndex(where: { $0.id == ruleUUID }) {
                    comboRules[index].source = newCombo
                    saveComboRules()
                    showBanner("已更新组合键映射「\(comboRules[index].name)」")
                }

            case .hidRemap:
                showBanner("请在「底层改键」页面编辑硬件单键映射", isError: false)
            }

            recomputeConflicts()
        } catch {
            showBanner("更新快捷键失败：\(error.localizedDescription)", isError: true)
        }
    }

    func toggleShortcut(_ item: ShortcutItem, enabled: Bool) {
        do {
            switch item.source {
            case .systemSymbolic:
                let sid = symbolicID(for: item)
                try symbolicStore.setEnabled(id: sid, enabled: enabled)
                systemShortcuts = symbolicStore.loadShortcuts()
                showBanner("\(enabled ? "已启用" : "已禁用")系统快捷键「\(item.title)」")

            case .devTool:
                guard let toolID = item.metadata["toolID"],
                      let adapter = devToolRegistry.adapter(forToolID: toolID),
                      adapter.supportsWrite else {
                    showBanner("\(item.appName) 暂不支持禁用/启用操作", isError: true)
                    return
                }
                let rawCommand = item.metadata["command"] ?? item.title
                if toolID == "vscode" || toolID == "cursor" || toolID == "antigravity",
                   let combo = item.combo {
                    let cleanCommand = rawCommand.hasPrefix("-") ? String(rawCommand.dropFirst()) : rawCommand
                    let updatedCommand = enabled ? cleanCommand : "-\(cleanCommand)"
                    try adapter.upsertShortcut(
                        command: updatedCommand,
                        combo: combo,
                        when: item.metadata["when"],
                        originalCommand: rawCommand
                    )
                    devToolInfos = devToolRegistry.detectAll()
                    devToolShortcuts = devToolRegistry.loadAllShortcuts()
                    showBanner("\(enabled ? "已启用" : "已禁用") \(item.appName)「\(cleanCommand)」")
                } else if !enabled {
                    try adapter.removeShortcut(itemID: item.id)
                    devToolInfos = devToolRegistry.detectAll()
                    devToolShortcuts = devToolRegistry.loadAllShortcuts()
                    showBanner("已移除 \(item.appName) 快捷键「\(rawCommand)」")
                }

            case .appMenu:
                if !enabled && item.isModified {
                    resetShortcut(item)
                    return
                }
                showBanner("系统菜单项不支持直接禁用，可移除自定义覆盖或更换快捷键")

            case .hidRemap:
                if let ruleIDString = item.metadata["ruleID"],
                   let ruleUUID = UUID(uuidString: ruleIDString),
                   let index = hidRules.firstIndex(where: { $0.id == ruleUUID }) {
                    hidRules[index].isEnabled = enabled
                    applyHidRules()
                    return
                }

            case .comboRemap:
                if let ruleIDString = item.metadata["ruleID"],
                   let ruleUUID = UUID(uuidString: ruleIDString),
                   let index = comboRules.firstIndex(where: { $0.id == ruleUUID }) {
                    comboRules[index].isEnabled = enabled
                    saveComboRules()
                    return
                }
            }

            recomputeConflicts()
        } catch {
            showBanner("切换状态失败：\(error.localizedDescription)", isError: true)
        }
    }

    func resetShortcut(_ item: ShortcutItem) {
        do {
            switch item.source {
            case .systemSymbolic:
                let sid = symbolicID(for: item)
                try symbolicStore.resetToDefault(id: sid)
                systemShortcuts = symbolicStore.loadShortcuts()
                showBanner("已恢复系统快捷键「\(item.title)」默认设置")

            case .appMenu:
                let domain = item.appBundleID ?? AppMenuShortcutStore.globalDomain
                let menuKey = item.metadata["menuPath"] ?? item.metadata["menuTitle"] ?? item.title
                try appMenuStore.removeOverride(domain: domain, menuTitleOrPath: menuKey)
                customAppOverrides = appMenuStore.loadOverrideShortcutItems()
                if domain != AppMenuShortcutStore.globalDomain {
                    appNeedsRestartBundleID = domain
                    if selectedAppBundleID == domain,
                       let app = runningApps.first(where: { $0.bundleID == domain }) {
                        Task { await selectAndScanApp(app) }
                    }
                    showBanner("已移除「\(item.title)」的自定义快捷键，重启 \(item.appName) 后生效")
                } else {
                    showBanner("已移除全局菜单快捷键「\(item.title)」")
                }

            case .devTool:
                guard let toolID = item.metadata["toolID"],
                      let adapter = devToolRegistry.adapter(forToolID: toolID),
                      adapter.supportsWrite else {
                    showBanner("\(item.appName) 不支持自动恢复", isError: true)
                    return
                }
                if let defaultCombo = item.defaultCombo {
                    let command = item.metadata["command"] ?? item.title
                    try adapter.upsertShortcut(
                        command: command,
                        combo: defaultCombo,
                        when: item.metadata["when"],
                        originalCommand: command
                    )
                } else {
                    try adapter.removeShortcut(itemID: item.id)
                }
                devToolInfos = devToolRegistry.detectAll()
                devToolShortcuts = devToolRegistry.loadAllShortcuts()
                showBanner("已重置 \(item.appName) 快捷键「\(item.title)」")

            case .hidRemap, .comboRemap:
                showBanner("请在「底层改键」页面管理映射规则")
            }

            recomputeConflicts()
        } catch {
            showBanner("恢复默认失败：\(error.localizedDescription)", isError: true)
        }
    }

    func addAppMenuShortcut(bundleID: String, appName: String, menuTitle: String, combo: KeyCombo) {
        let trimmedMenu = menuTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMenu.isEmpty else {
            showBanner("请输入菜单项名称或路径", isError: true)
            return
        }

        do {
            try appMenuStore.setOverride(
                domain: bundleID,
                appName: appName,
                menuTitleOrPath: trimmedMenu,
                combo: combo
            )
            customAppOverrides = appMenuStore.loadOverrideShortcutItems()
            if bundleID != AppMenuShortcutStore.globalDomain {
                appNeedsRestartBundleID = bundleID
                if selectedAppBundleID == bundleID,
                   let app = runningApps.first(where: { $0.bundleID == bundleID }) {
                    Task { await selectAndScanApp(app) }
                }
            }
            recomputeConflicts()
            showBanner("已添加菜单快捷键「\(trimmedMenu)」→ \(combo.displayString)")
        } catch {
            showBanner("添加菜单快捷键失败：\(error.localizedDescription)", isError: true)
        }
    }

    func addDevToolShortcut(toolID: String, command: String, combo: KeyCombo, when: String?) {
        let trimmedCmd = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCmd.isEmpty else {
            showBanner("请输入命令名称", isError: true)
            return
        }
        guard let adapter = devToolRegistry.adapter(forToolID: toolID) else {
            showBanner("未找到工具适配器：\(toolID)", isError: true)
            return
        }
        guard adapter.supportsWrite else {
            showBanner("\(adapter.displayName) 为只读集成，无法写入新快捷键", isError: true)
            return
        }

        do {
            let trimmedWhen = when?.trimmingCharacters(in: .whitespacesAndNewlines)
            try adapter.upsertShortcut(
                command: trimmedCmd,
                combo: combo,
                when: (trimmedWhen?.isEmpty == false) ? trimmedWhen : nil,
                originalCommand: nil
            )
            devToolInfos = devToolRegistry.detectAll()
            devToolShortcuts = devToolRegistry.loadAllShortcuts()
            recomputeConflicts()
            showBanner("已在 \(adapter.displayName) 添加快捷键「\(trimmedCmd)」")
        } catch {
            showBanner("添加开发工具快捷键失败：\(error.localizedDescription)", isError: true)
        }
    }

    func removeDevToolShortcut(toolID: String, item: ShortcutItem) {
        guard let adapter = devToolRegistry.adapter(forToolID: toolID) else {
            showBanner("未找到工具适配器：\(toolID)", isError: true)
            return
        }
        guard adapter.supportsWrite else {
            showBanner("\(adapter.displayName) 为只读集成，无法删除快捷键", isError: true)
            return
        }

        do {
            try adapter.removeShortcut(itemID: item.id)
            devToolInfos = devToolRegistry.detectAll()
            devToolShortcuts = devToolRegistry.loadAllShortcuts()
            recomputeConflicts()
            showBanner("已从 \(adapter.displayName) 移除快捷键「\(item.title)」")
        } catch {
            showBanner("移除开发工具快捷键失败：\(error.localizedDescription)", isError: true)
        }
    }

    // MARK: - HID & Combo Remapping

    func applyHidRules() {
        do {
            try hidManager.applyRules(hidRules)
            if isHidLaunchAgentInstalled {
                try hidManager.installLaunchAgent(for: hidRules)
            }
            recomputeConflicts()
            let activeCount = hidRules.filter(\.isEnabled).count
            showBanner("已应用 \(activeCount) 条硬件单键映射规则")
        } catch {
            showBanner("应用硬件改键失败：\(error.localizedDescription)", isError: true)
        }
    }

    func clearHidRules() {
        do {
            try hidManager.resetAllMappings()
            for idx in hidRules.indices {
                hidRules[idx].isEnabled = false
            }
            try hidManager.saveRules(hidRules)
            if isHidLaunchAgentInstalled {
                try hidManager.removeLaunchAgent()
                isHidLaunchAgentInstalled = hidManager.isLaunchAgentInstalled()
            }
            recomputeConflicts()
            showBanner("已重置所有硬件单键映射")
        } catch {
            showBanner("重置硬件改键失败：\(error.localizedDescription)", isError: true)
        }
    }

    func setHidLaunchAgent(enabled: Bool) {
        do {
            if enabled {
                try hidManager.installLaunchAgent(for: hidRules)
                showBanner("已安装登录自启 LaunchAgent，重启后依然生效")
            } else {
                try hidManager.removeLaunchAgent()
                showBanner("已移除硬件改键开机自启项")
            }
            isHidLaunchAgentInstalled = hidManager.isLaunchAgentInstalled()
        } catch {
            isHidLaunchAgentInstalled = hidManager.isLaunchAgentInstalled()
            showBanner("配置自启项失败：\(error.localizedDescription)", isError: true)
        }
    }

    func saveComboRules() {
        do {
            try comboRemapEngine.saveRules(comboRules)
            comboRules = comboRemapEngine.loadRules()
            recomputeConflicts()
        } catch {
            showBanner("保存组合键规则失败：\(error.localizedDescription)", isError: true)
        }
    }

    func toggleComboRemapEngine(_ enabled: Bool) {
        if enabled {
            saveComboRules()
            let started = comboRemapEngine.start()
            isComboRemapRunning = comboRemapEngine.isRunning
            refreshPermissions()
            if started {
                showBanner("组合键重映射引擎已启动")
            } else {
                showBanner("无法启动组合键重映射引擎：请先授予「输入监控」权限", isError: true)
            }
        } else {
            comboRemapEngine.stop()
            isComboRemapRunning = comboRemapEngine.isRunning
            showBanner("已停止组合键重映射引擎")
        }
    }

    // MARK: - Snapshots & Backup

    func createSnapshot(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let snapshotName = trimmed.isEmpty ? Self.defaultSnapshotName() : trimmed
        let snapshot = buildCurrentSnapshot(name: snapshotName)
        do {
            try snapshotManager.saveSnapshot(snapshot)
            snapshots = snapshotManager.listSnapshots()
            showBanner("已创建快照「\(snapshotName)」")
        } catch {
            showBanner("创建快照失败：\(error.localizedDescription)", isError: true)
        }
    }

    func restoreSnapshot(_ snapshot: KeyMapSnapshot) {
        do {
            try symbolicStore.restoreStates(snapshot.symbolicHotkeys)
            try appMenuStore.restoreAllOverrides(snapshot.appMenuOverrides)
            hidRules = snapshot.hidRules
            try hidManager.applyRules(hidRules)
            comboRules = snapshot.comboRules
            try comboRemapEngine.saveRules(comboRules)
            try devToolRegistry.importAllRecords(snapshot.devToolOverrides)

            Task { @MainActor in
                await refreshAll()
                showBanner("已恢复快照「\(snapshot.name)」")
            }
        } catch {
            showBanner("恢复快照失败：\(error.localizedDescription)", isError: true)
        }
    }

    func deleteSnapshot(_ snapshot: KeyMapSnapshot) {
        do {
            try snapshotManager.deleteSnapshot(id: snapshot.id)
            snapshots = snapshotManager.listSnapshots()
            showBanner("已删除快照「\(snapshot.name)」")
        } catch {
            showBanner("删除快照失败：\(error.localizedDescription)", isError: true)
        }
    }

    func exportSnapshotJSON(to url: URL) {
        let snapshot = buildCurrentSnapshot(name: Self.defaultSnapshotName())
        do {
            try snapshotManager.exportJSON(snapshot, to: url)
            showBanner("已导出配置到 \(url.lastPathComponent)")
        } catch {
            showBanner("导出 JSON 失败：\(error.localizedDescription)", isError: true)
        }
    }

    func importSnapshotJSON(from url: URL) {
        do {
            let imported = try snapshotManager.importJSON(from: url)
            try snapshotManager.saveSnapshot(imported)
            snapshots = snapshotManager.listSnapshots()
            showBanner("已导入快照「\(imported.name)」")
        } catch {
            showBanner("导入 JSON 失败：\(error.localizedDescription)", isError: true)
        }
    }

    // MARK: - Global Hotkey & App Lifecycle

    func updateOverlayHotKey(_ combo: KeyCombo) {
        if overlayHotKey == combo {
            return
        }
        overlayHotKey = combo
        Self.saveOverlayHotKey(combo)
        onOverlayHotKeyChanged?(combo)
        showBanner("已更新快捷浮窗呼出热键为 \(combo.displayString)")
    }

    func restartApp(bundleID: String) {
        let runningMatches = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        let appURL = runningMatches.first?.bundleURL ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)

        for app in runningMatches {
            app.terminate()
        }

        if appNeedsRestartBundleID == bundleID {
            appNeedsRestartBundleID = nil
        }

        guard let appURL else {
            showBanner("无法定位应用路径，请手动重启目标应用", isError: true)
            return
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 650_000_000)
            let config = NSWorkspace.OpenConfiguration()
            config.activates = false
            do {
                try await NSWorkspace.shared.openApplication(at: appURL, configuration: config)
                if let running = axScanner.listRunningApps().first(where: { $0.bundleID == bundleID }) {
                    self.runningApps = axScanner.listRunningApps()
                    if self.selectedAppBundleID == bundleID {
                        await self.selectAndScanApp(running)
                    }
                }
                self.showBanner("已重启目标应用，新快捷键现已生效")
            } catch {
                self.showBanner("重启应用失败：\(error.localizedDescription)", isError: true)
            }
        }
    }

    // MARK: - Banners

    func dismissBanner() {
        bannerDismissTask?.cancel()
        bannerDismissTask = nil
        bannerMessage = nil
        bannerIsError = false
    }

    func showBanner(_ message: String, isError: Bool = false) {
        bannerDismissTask?.cancel()
        bannerMessage = message
        bannerIsError = isError

        if !isError {
            bannerDismissTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                guard !Task.isCancelled else { return }
                if self?.bannerMessage == message {
                    self?.bannerMessage = nil
                }
            }
        }
    }

    // MARK: - Helpers

    func conflicts(for item: ShortcutItem) -> [ConflictItem] {
        conflicts.filter { conflict in
            conflict.items.contains(where: { $0.id == item.id })
        }
    }

    private func recomputeConflicts() {
        conflicts = ConflictDetector.detect(in: allShortcuts)
    }

    private func symbolicID(for item: ShortcutItem) -> String {
        if let sid = item.metadata["symbolicID"], !sid.isEmpty {
            return sid
        }
        if item.id.hasPrefix("symbolic.") {
            return String(item.id.dropFirst("symbolic.".count))
        }
        return item.id
    }

    private var hidRuleShortcutItems: [ShortcutItem] {
        hidRules.map { rule in
            let sourceDef = KeyCodeCatalog.definition(forHIDUsage: rule.sourceUsage)
            let targetDef = KeyCodeCatalog.definition(forHIDUsage: rule.targetUsage)
            let sourceCombo = sourceDef.map { KeyCombo(keyCode: $0.virtualKeyCode, modifiers: []) }
            let srcLabel = sourceDef?.label ?? String(format: "0x%llX", rule.sourceUsage)
            let dstLabel = targetDef?.label ?? String(format: "0x%llX", rule.targetUsage)

            return ShortcutItem(
                id: "hid.\(rule.id.uuidString)",
                title: rule.name.isEmpty ? "\(srcLabel) → \(dstLabel)" : rule.name,
                subtitle: "硬件单键映射：\(srcLabel) → \(dstLabel)",
                category: "硬件单键重映射",
                source: .hidRemap,
                appBundleID: nil,
                appName: "系统 HID",
                combo: sourceCombo,
                defaultCombo: nil,
                isEnabled: rule.isEnabled,
                isModified: true,
                isEditable: false,
                metadata: [
                    "ruleID": rule.id.uuidString,
                    "sourceUsage": String(rule.sourceUsage),
                    "targetUsage": String(rule.targetUsage)
                ]
            )
        }
    }

    private var comboRuleShortcutItems: [ShortcutItem] {
        comboRules.map { rule in
            let targetAppName: String = {
                guard let bid = rule.targetAppBundleID, !bid.isEmpty else { return "全局" }
                return runningApps.first(where: { $0.bundleID == bid })?.name ?? bid
            }()
            var meta: [String: String] = [
                "ruleID": rule.id.uuidString,
                "targetCombo": rule.target.displayString
            ]
            if let bid = rule.targetAppBundleID, !bid.isEmpty {
                meta["targetAppBundleID"] = bid
            }

            return ShortcutItem(
                id: "combo.\(rule.id.uuidString)",
                title: rule.name.isEmpty ? "\(rule.source.displayString) → \(rule.target.displayString)" : rule.name,
                subtitle: "映射为 \(rule.target.displayString) · \(targetAppName)",
                category: "组合键重映射",
                source: .comboRemap,
                appBundleID: rule.targetAppBundleID,
                appName: targetAppName,
                combo: rule.source,
                defaultCombo: rule.target,
                isEnabled: rule.isEnabled,
                isModified: true,
                isEditable: false,
                metadata: meta
            )
        }
    }

    private func buildCurrentSnapshot(name: String) -> KeyMapSnapshot {
        KeyMapSnapshot(
            id: UUID(),
            name: name,
            createdAt: Date(),
            schemaVersion: 1,
            symbolicHotkeys: symbolicStore.exportStates(),
            appMenuOverrides: appMenuStore.loadAllOverrides(),
            hidRules: hidRules,
            comboRules: comboRules,
            devToolOverrides: devToolRegistry.exportAllRecords()
        )
    }

    private static func defaultSnapshotName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return "备份 \(formatter.string(from: Date()))"
    }

    private static func loadSavedOverlayHotKey() -> KeyCombo {
        if let data = UserDefaults.standard.data(forKey: overlayHotKeyDefaultsKey),
           let decoded = try? JSONDecoder().decode(KeyCombo.self, from: data) {
            return decoded
        }
        return KeyCombo(keyCode: 40, modifiers: [.option, .command]) // ⌥⌘K
    }

    private static func saveOverlayHotKey(_ combo: KeyCombo) {
        if let encoded = try? JSONEncoder().encode(combo) {
            UserDefaults.standard.set(encoded, forKey: overlayHotKeyDefaultsKey)
        }
    }
}
