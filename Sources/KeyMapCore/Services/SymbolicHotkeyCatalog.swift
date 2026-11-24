import Foundation

public struct SymbolicHotkeyDefinition: Sendable, Hashable {
    public let id: String
    public let title: String
    public let category: String
    public let defaultEnabled: Bool
    public let defaultASCII: Int
    public let defaultVirtualKeyCode: UInt16
    public let defaultModifiers: UInt64

    public init(
        id: String,
        title: String,
        category: String,
        defaultEnabled: Bool,
        defaultASCII: Int,
        defaultVirtualKeyCode: UInt16,
        defaultModifiers: UInt64
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.defaultEnabled = defaultEnabled
        self.defaultASCII = defaultASCII
        self.defaultVirtualKeyCode = defaultVirtualKeyCode
        self.defaultModifiers = defaultModifiers
    }

    public var defaultCombo: KeyCombo? {
        guard defaultVirtualKeyCode != UInt16.max else {
            return nil
        }
        return KeyCombo(
            keyCode: defaultVirtualKeyCode,
            modifiers: KeyModifiers(symbolicBitmask: defaultModifiers)
        )
    }
}

public enum SymbolicHotkeyCatalog {
    private enum Mod {
        static let shift: UInt64 = 1 << 17
        static let control: UInt64 = 1 << 18
        static let option: UInt64 = 1 << 19
        static let command: UInt64 = 1 << 20
    }

    public static let entries: [SymbolicHotkeyDefinition] = [
        // MARK: - 聚焦搜索 (Spotlight)
        SymbolicHotkeyDefinition(
            id: "64",
            title: "显示聚焦搜索",
            category: "聚焦搜索",
            defaultEnabled: true,
            defaultASCII: 32,
            defaultVirtualKeyCode: 49,
            defaultModifiers: Mod.command
        ),
        SymbolicHotkeyDefinition(
            id: "65",
            title: "显示“访达”搜索窗口",
            category: "聚焦搜索",
            defaultEnabled: true,
            defaultASCII: 32,
            defaultVirtualKeyCode: 49,
            defaultModifiers: Mod.option | Mod.command
        ),

        // MARK: - 输入法 (Input Sources)
        SymbolicHotkeyDefinition(
            id: "60",
            title: "选择上一个输入法",
            category: "输入法",
            defaultEnabled: true,
            defaultASCII: 32,
            defaultVirtualKeyCode: 49,
            defaultModifiers: Mod.control
        ),
        SymbolicHotkeyDefinition(
            id: "61",
            title: "选择输入法菜单中的下一个输入法",
            category: "输入法",
            defaultEnabled: true,
            defaultASCII: 32,
            defaultVirtualKeyCode: 49,
            defaultModifiers: Mod.control | Mod.option
        ),

        // MARK: - 截屏 (Screenshots)
        SymbolicHotkeyDefinition(
            id: "28",
            title: "将整个屏幕图片存储为文件",
            category: "截屏",
            defaultEnabled: true,
            defaultASCII: 51,
            defaultVirtualKeyCode: 20,
            defaultModifiers: Mod.shift | Mod.command
        ),
        SymbolicHotkeyDefinition(
            id: "29",
            title: "将整个屏幕图片拷贝到剪贴板",
            category: "截屏",
            defaultEnabled: true,
            defaultASCII: 51,
            defaultVirtualKeyCode: 20,
            defaultModifiers: Mod.control | Mod.shift | Mod.command
        ),
        SymbolicHotkeyDefinition(
            id: "30",
            title: "将所选区域图片存储为文件",
            category: "截屏",
            defaultEnabled: true,
            defaultASCII: 52,
            defaultVirtualKeyCode: 21,
            defaultModifiers: Mod.shift | Mod.command
        ),
        SymbolicHotkeyDefinition(
            id: "31",
            title: "将所选区域图片拷贝到剪贴板",
            category: "截屏",
            defaultEnabled: true,
            defaultASCII: 52,
            defaultVirtualKeyCode: 21,
            defaultModifiers: Mod.control | Mod.shift | Mod.command
        ),
        SymbolicHotkeyDefinition(
            id: "184",
            title: "截屏与录制选项",
            category: "截屏",
            defaultEnabled: true,
            defaultASCII: 53,
            defaultVirtualKeyCode: 23,
            defaultModifiers: Mod.shift | Mod.command
        ),

        // MARK: - 调度中心与空间 (Mission Control & Spaces)
        SymbolicHotkeyDefinition(
            id: "32",
            title: "调度中心 (Mission Control)",
            category: "调度中心与空间",
            defaultEnabled: true,
            defaultASCII: 65535,
            defaultVirtualKeyCode: 126,
            defaultModifiers: Mod.control
        ),
        SymbolicHotkeyDefinition(
            id: "33",
            title: "应用程序窗口",
            category: "调度中心与空间",
            defaultEnabled: true,
            defaultASCII: 65535,
            defaultVirtualKeyCode: 125,
            defaultModifiers: Mod.control
        ),
        SymbolicHotkeyDefinition(
            id: "34",
            title: "调度中心 (慢动作)",
            category: "调度中心与空间",
            defaultEnabled: false,
            defaultASCII: 65535,
            defaultVirtualKeyCode: 126,
            defaultModifiers: Mod.control | Mod.shift
        ),
        SymbolicHotkeyDefinition(
            id: "35",
            title: "应用程序窗口 (慢动作)",
            category: "调度中心与空间",
            defaultEnabled: false,
            defaultASCII: 65535,
            defaultVirtualKeyCode: 125,
            defaultModifiers: Mod.control | Mod.shift
        ),
        SymbolicHotkeyDefinition(
            id: "36",
            title: "显示桌面",
            category: "调度中心与空间",
            defaultEnabled: true,
            defaultASCII: 65535,
            defaultVirtualKeyCode: 103,
            defaultModifiers: 0
        ),
        SymbolicHotkeyDefinition(
            id: "37",
            title: "显示桌面 (慢动作)",
            category: "调度中心与空间",
            defaultEnabled: false,
            defaultASCII: 65535,
            defaultVirtualKeyCode: 103,
            defaultModifiers: Mod.shift
        ),
        SymbolicHotkeyDefinition(
            id: "79",
            title: "向左移动一个空间",
            category: "调度中心与空间",
            defaultEnabled: true,
            defaultASCII: 65535,
            defaultVirtualKeyCode: 123,
            defaultModifiers: Mod.control
        ),
        SymbolicHotkeyDefinition(
            id: "80",
            title: "向左移动一个空间 (慢动作)",
            category: "调度中心与空间",
            defaultEnabled: false,
            defaultASCII: 65535,
            defaultVirtualKeyCode: 123,
            defaultModifiers: Mod.control | Mod.shift
        ),
        SymbolicHotkeyDefinition(
            id: "81",
            title: "向右移动一个空间",
            category: "调度中心与空间",
            defaultEnabled: true,
            defaultASCII: 65535,
            defaultVirtualKeyCode: 124,
            defaultModifiers: Mod.control
        ),
        SymbolicHotkeyDefinition(
            id: "82",
            title: "向右移动一个空间 (慢动作)",
            category: "调度中心与空间",
            defaultEnabled: false,
            defaultASCII: 65535,
            defaultVirtualKeyCode: 124,
            defaultModifiers: Mod.control | Mod.shift
        ),
        SymbolicHotkeyDefinition(
            id: "118",
            title: "切换到桌面 1",
            category: "调度中心与空间",
            defaultEnabled: false,
            defaultASCII: 49,
            defaultVirtualKeyCode: 18,
            defaultModifiers: Mod.control
        ),
        SymbolicHotkeyDefinition(
            id: "119",
            title: "切换到桌面 2",
            category: "调度中心与空间",
            defaultEnabled: false,
            defaultASCII: 50,
            defaultVirtualKeyCode: 19,
            defaultModifiers: Mod.control
        ),
        SymbolicHotkeyDefinition(
            id: "120",
            title: "切换到桌面 3",
            category: "调度中心与空间",
            defaultEnabled: false,
            defaultASCII: 51,
            defaultVirtualKeyCode: 20,
            defaultModifiers: Mod.control
        ),
        SymbolicHotkeyDefinition(
            id: "121",
            title: "切换到桌面 4",
            category: "调度中心与空间",
            defaultEnabled: false,
            defaultASCII: 52,
            defaultVirtualKeyCode: 21,
            defaultModifiers: Mod.control
        ),
        SymbolicHotkeyDefinition(
            id: "122",
            title: "切换到桌面 5",
            category: "调度中心与空间",
            defaultEnabled: false,
            defaultASCII: 53,
            defaultVirtualKeyCode: 23,
            defaultModifiers: Mod.control
        ),
        SymbolicHotkeyDefinition(
            id: "123",
            title: "切换到桌面 6",
            category: "调度中心与空间",
            defaultEnabled: false,
            defaultASCII: 54,
            defaultVirtualKeyCode: 22,
            defaultModifiers: Mod.control
        ),
        SymbolicHotkeyDefinition(
            id: "124",
            title: "切换到桌面 7",
            category: "调度中心与空间",
            defaultEnabled: false,
            defaultASCII: 55,
            defaultVirtualKeyCode: 26,
            defaultModifiers: Mod.control
        ),
        SymbolicHotkeyDefinition(
            id: "125",
            title: "切换到桌面 8",
            category: "调度中心与空间",
            defaultEnabled: false,
            defaultASCII: 56,
            defaultVirtualKeyCode: 28,
            defaultModifiers: Mod.control
        ),
        SymbolicHotkeyDefinition(
            id: "126",
            title: "切换到桌面 9",
            category: "调度中心与空间",
            defaultEnabled: false,
            defaultASCII: 57,
            defaultVirtualKeyCode: 25,
            defaultModifiers: Mod.control
        ),

        // MARK: - 程序坞、启动台与快速备忘录 (Dock, Launchpad & System)
        SymbolicHotkeyDefinition(
            id: "52",
            title: "打开/关闭自动隐藏程序坞",
            category: "程序坞与系统",
            defaultEnabled: true,
            defaultASCII: 100,
            defaultVirtualKeyCode: 2,
            defaultModifiers: Mod.option | Mod.command
        ),
        SymbolicHotkeyDefinition(
            id: "98",
            title: "在词典中查询",
            category: "程序坞与系统",
            defaultEnabled: false,
            defaultASCII: 100,
            defaultVirtualKeyCode: 2,
            defaultModifiers: Mod.control | Mod.command
        ),
        SymbolicHotkeyDefinition(
            id: "160",
            title: "显示启动台 (Launchpad)",
            category: "程序坞与系统",
            defaultEnabled: false,
            defaultASCII: 65535,
            defaultVirtualKeyCode: UInt16.max,
            defaultModifiers: 0
        ),
        SymbolicHotkeyDefinition(
            id: "163",
            title: "显示通知中心",
            category: "程序坞与系统",
            defaultEnabled: false,
            defaultASCII: 65535,
            defaultVirtualKeyCode: UInt16.max,
            defaultModifiers: 0
        ),
        SymbolicHotkeyDefinition(
            id: "175",
            title: "打开/关闭勿扰模式",
            category: "程序坞与系统",
            defaultEnabled: false,
            defaultASCII: 65535,
            defaultVirtualKeyCode: UInt16.max,
            defaultModifiers: 0
        ),
        SymbolicHotkeyDefinition(
            id: "190",
            title: "显示应用窗口 / 台前调度切换",
            category: "程序坞与系统",
            defaultEnabled: false,
            defaultASCII: 65535,
            defaultVirtualKeyCode: UInt16.max,
            defaultModifiers: 0
        ),
        SymbolicHotkeyDefinition(
            id: "222",
            title: "新建快速备忘录",
            category: "程序坞与系统",
            defaultEnabled: false,
            defaultASCII: 65535,
            defaultVirtualKeyCode: UInt16.max,
            defaultModifiers: 0
        ),

        // MARK: - 键盘与焦点切换 (Keyboard & Focus)
        SymbolicHotkeyDefinition(
            id: "7",
            title: "将焦点移到菜单栏",
            category: "键盘与焦点",
            defaultEnabled: true,
            defaultASCII: 65535,
            defaultVirtualKeyCode: 120,
            defaultModifiers: Mod.control
        ),
        SymbolicHotkeyDefinition(
            id: "8",
            title: "将焦点移到程序坞",
            category: "键盘与焦点",
            defaultEnabled: true,
            defaultASCII: 65535,
            defaultVirtualKeyCode: 99,
            defaultModifiers: Mod.control
        ),
        SymbolicHotkeyDefinition(
            id: "9",
            title: "将焦点移到活跃或下一个窗口",
            category: "键盘与焦点",
            defaultEnabled: true,
            defaultASCII: 65535,
            defaultVirtualKeyCode: 118,
            defaultModifiers: Mod.control
        ),
        SymbolicHotkeyDefinition(
            id: "10",
            title: "将焦点移到窗口工具栏",
            category: "键盘与焦点",
            defaultEnabled: true,
            defaultASCII: 65535,
            defaultVirtualKeyCode: 96,
            defaultModifiers: Mod.control
        ),
        SymbolicHotkeyDefinition(
            id: "11",
            title: "将焦点移到浮动窗口",
            category: "键盘与焦点",
            defaultEnabled: true,
            defaultASCII: 65535,
            defaultVirtualKeyCode: 97,
            defaultModifiers: Mod.control
        ),
        SymbolicHotkeyDefinition(
            id: "12",
            title: "更改 Tab 键移动焦点的方式",
            category: "键盘与焦点",
            defaultEnabled: true,
            defaultASCII: 65535,
            defaultVirtualKeyCode: 98,
            defaultModifiers: Mod.control
        ),
        SymbolicHotkeyDefinition(
            id: "13",
            title: "将焦点移到状态菜单",
            category: "键盘与焦点",
            defaultEnabled: true,
            defaultASCII: 65535,
            defaultVirtualKeyCode: 100,
            defaultModifiers: Mod.control
        ),
        SymbolicHotkeyDefinition(
            id: "27",
            title: "将焦点移到当前应用的下一个窗口",
            category: "键盘与焦点",
            defaultEnabled: true,
            defaultASCII: 96,
            defaultVirtualKeyCode: 50,
            defaultModifiers: Mod.command
        ),
        SymbolicHotkeyDefinition(
            id: "57",
            title: "打开或关闭全键盘控制",
            category: "键盘与焦点",
            defaultEnabled: true,
            defaultASCII: 65535,
            defaultVirtualKeyCode: 122,
            defaultModifiers: Mod.control
        ),
        SymbolicHotkeyDefinition(
            id: "59",
            title: "将焦点移到窗口抽屉",
            category: "键盘与焦点",
            defaultEnabled: false,
            defaultASCII: 39,
            defaultVirtualKeyCode: 39,
            defaultModifiers: Mod.option | Mod.command
        ),

        // MARK: - 辅助功能 (Accessibility)
        SymbolicHotkeyDefinition(
            id: "15",
            title: "打开或关闭缩放",
            category: "辅助功能",
            defaultEnabled: false,
            defaultASCII: 56,
            defaultVirtualKeyCode: 28,
            defaultModifiers: Mod.option | Mod.command
        ),
        SymbolicHotkeyDefinition(
            id: "16",
            title: "放大",
            category: "辅助功能",
            defaultEnabled: false,
            defaultASCII: 61,
            defaultVirtualKeyCode: 24,
            defaultModifiers: Mod.option | Mod.command
        ),
        SymbolicHotkeyDefinition(
            id: "17",
            title: "缩小",
            category: "辅助功能",
            defaultEnabled: false,
            defaultASCII: 45,
            defaultVirtualKeyCode: 27,
            defaultModifiers: Mod.option | Mod.command
        ),
        SymbolicHotkeyDefinition(
            id: "19",
            title: "打开或关闭图像平滑",
            category: "辅助功能",
            defaultEnabled: false,
            defaultASCII: 92,
            defaultVirtualKeyCode: 42,
            defaultModifiers: Mod.option | Mod.command
        ),
        SymbolicHotkeyDefinition(
            id: "21",
            title: "反转颜色",
            category: "辅助功能",
            defaultEnabled: false,
            defaultASCII: 56,
            defaultVirtualKeyCode: 28,
            defaultModifiers: Mod.control | Mod.option | Mod.command
        ),
        SymbolicHotkeyDefinition(
            id: "23",
            title: "打开或关闭旁白 (VoiceOver)",
            category: "辅助功能",
            defaultEnabled: false,
            defaultASCII: 65535,
            defaultVirtualKeyCode: 96,
            defaultModifiers: Mod.command
        ),
        SymbolicHotkeyDefinition(
            id: "25",
            title: "提高对比度",
            category: "辅助功能",
            defaultEnabled: false,
            defaultASCII: 46,
            defaultVirtualKeyCode: 47,
            defaultModifiers: Mod.control | Mod.option | Mod.command
        ),
        SymbolicHotkeyDefinition(
            id: "26",
            title: "降低对比度",
            category: "辅助功能",
            defaultEnabled: false,
            defaultASCII: 44,
            defaultVirtualKeyCode: 43,
            defaultModifiers: Mod.control | Mod.option | Mod.command
        )
    ]

    private static let byID: [String: SymbolicHotkeyDefinition] = {
        Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
    }()

    public static func definition(forID id: String) -> SymbolicHotkeyDefinition? {
        byID[id]
    }
}
