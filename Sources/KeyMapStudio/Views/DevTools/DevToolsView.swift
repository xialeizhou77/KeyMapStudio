import AppKit
import KeyMapCore
import SwiftUI

struct DevToolsView: View {
    let appState: AppState

    @State private var selectedToolID: String? = nil
    @State private var searchText: String = ""
    @State private var rebindingItem: ShortcutItem? = nil
    @State private var rebindDraftCombo: KeyCombo? = nil
    @State private var showAddSheet: Bool = false

    // Add DevTool Shortcut Sheet
    @State private var addToolID: String = "vscode"
    @State private var addCommand: String = ""
    @State private var addWhen: String = ""
    @State private var addCombo: KeyCombo? = nil

    init(appState: AppState) {
        self.appState = appState
    }

    private var writableTools: [DevToolInfo] {
        appState.devToolInfos.filter(\.supportsWrite)
    }

    private var filteredShortcuts: [ShortcutItem] {
        appState.devToolShortcuts.filter { item in
            if let selectedToolID {
                guard item.metadata["toolID"] == selectedToolID else { return false }
            }
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !query.isEmpty else { return true }
            let fields = [
                item.title,
                item.subtitle,
                item.appName,
                item.metadata["command"] ?? "",
                item.metadata["when"] ?? "",
                item.combo?.displayString ?? "",
            ]
            return fields.contains { $0.lowercased().contains(query) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    toolStatusGrid
                    filterAndSearchBar
                    shortcutsListSection
                }
                .padding(20)
            }
        }
        .sheet(item: $rebindingItem) { item in
            rebindSheet(for: item)
        }
        .sheet(isPresented: $showAddSheet) {
            addDevToolShortcutSheet
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("开发工具快捷键")
                    .font(.title3.weight(.semibold))
                Text("统一管理 VS Code、Cursor、Antigravity、iTerm2、Raycast 与 Obsidian 配置")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task { await appState.refreshAll() }
            } label: {
                Label("重新扫描", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)

            Button {
                if let firstWritable = writableTools.first {
                    addToolID = selectedToolID.flatMap { id in
                        writableTools.contains(where: { $0.id == id }) ? id : nil
                    } ?? firstWritable.id
                }
                addCommand = ""
                addWhen = ""
                addCombo = nil
                showAddSheet = true
            } label: {
                Label("新增快捷键", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .disabled(writableTools.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }

    // MARK: - Tool Status Cards Grid

    private var toolStatusGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 235, maximum: 340), spacing: 12)], spacing: 12) {
            ForEach(appState.devToolInfos) { info in
                toolStatusCard(info)
            }
        }
    }

    private func toolStatusCard(_ info: DevToolInfo) -> some View {
        let isSelected = selectedToolID == info.id

        return GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: iconName(for: info.id))
                        .font(.title3)
                        .foregroundStyle(Color.purple)
                        .frame(width: 26, height: 26)
                        .background(Color.purple.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(info.name)
                                .font(.headline)
                            if !info.supportsWrite {
                                Text("只读")
                                    .font(.caption2)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(.secondary.opacity(0.16), in: Capsule())
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text(info.bundleID)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text("\(info.shortcutCount)")
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(.purple)
                }

                HStack(spacing: 6) {
                    statusPill(
                        label: info.isAppInstalled ? "已安装" : "未安装",
                        active: info.isAppInstalled,
                        activeColor: .green
                    )
                    statusPill(
                        label: info.hasConfigFile ? "配置存在" : "暂无配置",
                        active: info.hasConfigFile,
                        activeColor: .blue
                    )
                }

                Text(info.configPath)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(info.configPath)

                HStack {
                    Button {
                        selectedToolID = (selectedToolID == info.id) ? nil : info.id
                    } label: {
                        Text(isSelected ? "显示全部" : "筛选此工具")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Spacer()

                    Button {
                        revealInFinder(path: info.configPath)
                    } label: {
                        Label("在访达中显示", systemImage: "folder")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
            }
            .padding(4)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 1.5)
        )
    }

    private func statusPill(label: String, active: Bool, activeColor: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(active ? activeColor : Color.secondary.opacity(0.4))
                .frame(width: 6, height: 6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(active ? .primary : .secondary)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            (active ? activeColor : Color.secondary).opacity(0.12),
            in: Capsule()
        )
    }

    // MARK: - Filter Tabs & Search

    private var filterAndSearchBar: some View {
        HStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    toolFilterButton(title: "全部 (\(appState.devToolShortcuts.count))", toolID: nil)
                    ForEach(appState.devToolInfos) { info in
                        toolFilterButton(title: "\(info.name) (\(info.shortcutCount))", toolID: info.id)
                    }
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索命令、when 条件或快捷键...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.1), lineWidth: 1))
            .frame(width: 260)
        }
    }

    private func toolFilterButton(title: String, toolID: String?) -> some View {
        let isSelected = selectedToolID == toolID
        return Button(title) {
            selectedToolID = toolID
        }
        .buttonStyle(.plain)
        .font(.caption.weight(isSelected ? .semibold : .regular))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            isSelected ? Color.purple : Color.secondary.opacity(0.12),
            in: Capsule()
        )
        .foregroundStyle(isSelected ? Color.white : Color.primary)
    }

    // MARK: - Shortcuts List

    private var shortcutsListSection: some View {
        Group {
            if filteredShortcuts.isEmpty {
                GroupBox {
                    ContentUnavailableView(
                        "无匹配的开发工具快捷键",
                        systemImage: "wrench.and.screwdriver",
                        description: Text("尝试清除搜索关键字，或点击右上角「新增快捷键」添加配置。")
                    )
                    .frame(maxWidth: .infinity, minHeight: 160)
                }
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(filteredShortcuts) { item in
                        devToolShortcutRow(item)
                    }
                }
            }
        }
    }

    private func devToolShortcutRow(_ item: ShortcutItem) -> some View {
        let toolID = item.metadata["toolID"] ?? ""
        let command = item.metadata["command"] ?? item.title
        let whenClause = item.metadata["when"]
        let supportsWrite = appState.devToolInfos.first(where: { $0.id == toolID })?.supportsWrite ?? item.isEditable

        return GroupBox {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.appName)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.16), in: Capsule())
                            .foregroundStyle(.purple)

                        if !item.isEnabled {
                            Text("已禁用 (-)")
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.14), in: Capsule())
                                .foregroundStyle(.red)
                        }

                        if let whenClause, !whenClause.isEmpty {
                            Text("when: \(whenClause)")
                                .font(.caption2.monospaced())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 4))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Text(command)
                        .font(.body.monospaced().weight(.medium))
                        .lineLimit(1)

                    if !item.subtitle.isEmpty && item.subtitle != command {
                        Text(item.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                KeyCapBadge(combo: item.combo, size: .regular)

                if supportsWrite && item.isEditable {
                    Button("修改") {
                        rebindDraftCombo = item.combo
                        rebindingItem = item
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(role: .destructive) {
                        appState.removeDevToolShortcut(toolID: toolID, item: item)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("从配置文件移除此快捷键")
                }
            }
            .padding(4)
        }
    }

    // MARK: - Sheets

    private func rebindSheet(for item: ShortcutItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("修改快捷键 — \(item.appName)")
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 6) {
                Text(item.metadata["command"] ?? item.title)
                    .font(.body.monospaced())
                if let whenClause = item.metadata["when"], !whenClause.isEmpty {
                    Text("when: \(whenClause)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text("新快捷键:")
                Spacer()
                ShortcutRecorderView(
                    combo: $rebindDraftCombo,
                    allowEmpty: false,
                    placeholder: "点击录制新快捷键",
                    onRecordingChanged: { appState.isRecordingShortcut = $0 }
                )
                .frame(width: 220)
            }

            HStack {
                Spacer()
                Button("取消") {
                    appState.isRecordingShortcut = false
                    rebindingItem = nil
                }
                .keyboardShortcut(.cancelAction)

                Button("保存") {
                    if let newCombo = rebindDraftCombo {
                        appState.updateShortcut(item, newCombo: newCombo)
                    }
                    appState.isRecordingShortcut = false
                    rebindingItem = nil
                }
                .buttonStyle(.borderedProminent)
                .disabled(rebindDraftCombo == nil)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 440)
        .onDisappear {
            appState.isRecordingShortcut = false
        }
    }

    private var addDevToolShortcutSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("新增开发工具快捷键")
                .font(.title3.weight(.semibold))

            Form {
                Picker("目标工具", selection: $addToolID) {
                    ForEach(writableTools) { tool in
                        Text(tool.name).tag(tool.id)
                    }
                }

                TextField("命令 ID (如 workbench.action.quickOpen)", text: $addCommand)
                    .font(.body.monospaced())

                TextField("when 条件 (可选，如 editorTextFocus)", text: $addWhen)
                    .font(.body.monospaced())

                LabeledContent("快捷键") {
                    ShortcutRecorderView(
                        combo: $addCombo,
                        allowEmpty: false,
                        placeholder: "点击录制快捷键",
                        onRecordingChanged: { appState.isRecordingShortcut = $0 }
                    )
                    .frame(width: 210)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("取消") {
                    appState.isRecordingShortcut = false
                    showAddSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Button("写入配置") {
                    let cmd = addCommand.trimmingCharacters(in: .whitespacesAndNewlines)
                    let when = addWhen.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cmd.isEmpty, let combo = addCombo else { return }
                    appState.addDevToolShortcut(
                        toolID: addToolID,
                        command: cmd,
                        combo: combo,
                        when: when.isEmpty ? nil : when
                    )
                    appState.isRecordingShortcut = false
                    showAddSheet = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(addCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || addCombo == nil)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 480)
        .onDisappear {
            appState.isRecordingShortcut = false
        }
    }

    // MARK: - Helpers

    private func iconName(for toolID: String) -> String {
        switch toolID {
        case "vscode", "cursor", "antigravity":
            return "chevron.left.forwardslash.chevron.right"
        case "iterm2":
            return "terminal.fill"
        case "raycast":
            return "magnifyingglass.circle.fill"
        case "obsidian":
            return "doc.richtext.fill"
        default:
            return "wrench.and.screwdriver.fill"
        }
    }

    private func revealInFinder(path: String) {
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            let parent = url.deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: parent.path) {
                NSWorkspace.shared.activateFileViewerSelecting([parent])
            } else {
                appState.showBanner("配置文件及上级目录尚未创建: \(path)", isError: true)
            }
        }
    }
}
