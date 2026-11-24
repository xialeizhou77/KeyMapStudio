# KeyMapStudio 完整使用说明书

> 本文档面向 **KeyMapStudio v1.0.0**（macOS 14.0 Sonoma 及以上），全面覆盖从芯片选型安装、权限授权、8 大功能模块实操到完全还原卸载的全流程指南。

---

## 目录

1. [安装与芯片选择](#1-安装与芯片选择)
2. [权限向导与降级能力](#2-权限向导与降级能力)
3. [全局极速浮窗（Quick Overlay）](#3-全局极速浮窗quick-overlay)
4. [应用菜单快捷键（「应用与菜单」）](#4-应用菜单快捷键应用与菜单)
5. [macOS 系统快捷键（「系统快捷键」）](#5-macos-系统快捷键系统快捷键)
6. [交互式 78 键虚拟键盘（「交互式键盘」）](#6-交互式-78-键虚拟键盘交互式键盘)
7. [底层键位重映射（「底层改键」）](#7-底层键位重映射底层改键)
8. [开发工具配置聚合（「开发工具」）](#8-开发工具配置聚合开发工具)
9. [跨层全局冲突中心（「冲突中心」）](#9-跨层全局冲突中心冲突中心)
10. [配置快照备份与换机迁移（「快照与备份」）](#10-配置快照备份与换机迁移快照与备份)
11. [常见问题与完全恢复 / 卸载指南](#11-常见问题与完全恢复--卸载指南)

---

## 1. 安装与芯片选择

### 1.1 判断你的 Mac 芯片架构

KeyMapStudio 提供针对不同 CPU 原生编译的独立分发包：

| 芯片类型 | 架构标识 | 适用机型 | 推荐下载 |
| :--- | :--- | :--- | :--- |
| **Apple Silicon** | `arm64` | M1 / M2 / M3 / M4 系列芯片 Mac | [KeyMapStudio-AppleSilicon-arm64.dmg](https://github.com/xialeizhou77/KeyMapStudio/releases/latest/download/KeyMapStudio-AppleSilicon-arm64.dmg)（备选 [ZIP](https://github.com/xialeizhou77/KeyMapStudio/releases/latest/download/KeyMapStudio-AppleSilicon-arm64.zip)） |
| **Intel** | `x86_64` | 采用 Intel 处理器的 Mac | [KeyMapStudio-Intel-x86_64.dmg](https://github.com/xialeizhou77/KeyMapStudio/releases/latest/download/KeyMapStudio-Intel-x86_64.dmg)（备选 [ZIP](https://github.com/xialeizhou77/KeyMapStudio/releases/latest/download/KeyMapStudio-Intel-x86_64.zip)） |

查看方法：
- **系统界面**：点击屏幕左上角 ** → 关于本机**，查看 **芯片**（Apple M 系列选 `arm64`）或 **处理器**（Intel 选 `x86_64`）。
- **终端命令**：
  ```bash
  uname -m
  # arm64 -> Apple Silicon；x86_64 -> Intel
  ```

### 1.2 安装与 SHA256 校验

1. **校验完整性（可选）**：从 [Releases 页面](https://github.com/xialeizhou77/KeyMapStudio/releases) 下载对应安装包与 [SHA256SUMS.txt](https://github.com/xialeizhou77/KeyMapStudio/releases/latest/download/SHA256SUMS.txt) 后执行：
   ```bash
   shasum -a 256 -c SHA256SUMS.txt --ignore-missing
   ```
2. **DMG 安装（推荐）**：双击打开 `.dmg` 镜像，将 **KeyMapStudio.app** 拖入右侧的 **Applications** 快捷方式文件夹。
3. **ZIP 安装（备选）**：双击解压 `.zip`，将生成的 `KeyMapStudio.app` 拖入 `/Applications`（应用程序）文件夹。

### 1.3 解除 macOS Gatekeeper 首次运行隔离

由于 KeyMapStudio 为纯开源项目，Release 构建使用 **ad-hoc 本地签名**，未使用付费 Apple Developer ID 证书向 Apple 公证。浏览器下载的文件会带有 `com.apple.quarantine` 隔离属性，直接打开可能出现 **“无法打开，因为无法验证开发者”** 或 **“已损坏，无法打开”** 提示。

将应用拖入 `/Applications` 后，打开「终端」执行以下命令即可放行：

```bash
xattr -cr /Applications/KeyMapStudio.app
```

> **图形界面替代方案**：若先双击运行并关闭拦截弹窗，可前往 **系统设置 → 隐私与安全性 → 安全性**，点击底部的 **“仍要打开”**。

---

## 2. 权限向导与降级能力

在左侧边栏进入 **「权限与设置」**，可以看到两项 macOS 系统隐私权限的实时检测卡片，以及边栏底部的绿/橙色状态指示灯。

### 2.1 辅助功能（Accessibility）授权步骤

- **用途**：用于通过 macOS `AXUIElement` 接口实时读取任意运行中应用的菜单栏层级结构与当前快捷键绑定，并配合底层事件引擎控制。
- **授权步骤**：
  1. 在 **「权限与设置」** 的 **「辅助功能 (Accessibility)」** 卡片中点击 **「请求授权」** 触发系统提示，或直接点击 **「打开系统设置」**（直达 *隐私与安全性 → 辅助功能*）。
  2. 在列表找到 **KeyMapStudio** 并开启开关（若未出现在列表，可点击左下角 `+` 号从 `/Applications` 添加）。
  3. 回到 KeyMapStudio 点击右上角 **「刷新权限状态」** 或卡片内的 **「重新校验」**，指示灯变为绿色 **「已授权」** 即生效。

### 2.2 输入监控（Input Monitoring）授权步骤

- **用途**：用于 **「组合键重映射引擎 (CGEventTap)」** 在系统会话层捕获并改写组合键事件。
- **授权步骤**：
  1. 在 **「输入监控 (Input Monitoring)」** 卡片点击 **「请求授权」**，再点击 **「打开系统设置」**（直达 *隐私与安全性 → 输入监控*）。
  2. 勾选或开启 **KeyMapStudio** 开关（macOS 可能会提示重启应用，按提示重新打开即可）。
  3. 返回软件刷新状态，确认变为 **「已授权」**。

### 2.3 未授权下的降级可用能力对照

KeyMapStudio 在**零特殊权限**下仍可安全使用绝大多数核心能力：

| 功能模块 | 零权限（降级模式） | 仅开启「辅助功能」 | 同时开启「辅助功能 + 输入监控」 |
| :--- | :---: | :---: | :---: |
| **macOS 系统快捷键**读写与 `activateSettings -u` 刷新 | ✅ 完整可用 | ✅ 完整可用 | ✅ 完整可用 |
| **应用全局覆盖 (`NSGlobalDomain`)** 与手动录入 `->` 菜单改键 | ✅ 完整可用 | ✅ 完整可用 | ✅ 完整可用 |
| **实时扫描前台/指定应用菜单树** & 浮窗自动抓取菜单 | ❌ 提示需开启辅助功能 | ✅ 完整可用 | ✅ 完整可用 |
| **开发工具配置读写** (VS Code / Cursor / Antigravity / iTerm2 / Obsidian / Raycast) | ✅ 完整可用 | ✅ 完整可用 | ✅ 完整可用 |
| **硬件单键重映射 (`hidutil`)** 与 `LaunchAgent` 开机自启 | ✅ 完整可用 | ✅ 完整可用 | ✅ 完整可用 |
| **组合键重映射引擎 (`CGEventTap`)** 全局/分应用实时拦截 | ❌ 无法创建 EventTap | ❌ 无法启动引擎 | ✅ 完整可用 |
| **交互式键盘 / 冲突中心 / 快照与备份** | ✅ 基于已加载源可用 | ✅ 含实时应用菜单 | ✅ 全五层完整可用 |

---

## 3. 全局极速浮窗（Quick Overlay）

全局极速浮窗是一个无激活抢占式浮动面板（`NSPanel`），让你无需离开当前正在编辑的文档或终端即可快速查询快捷键。

### 3.1 唤起与自定义快捷键

- **默认全局热键**：在任意应用下按下 `⌥⌘K` 即可呼出，再按一次 `⌥⌘K`、按 `Esc` 或点击浮窗外任意区域即可隐藏。
- **其他呼出入口**：主窗口右上角工具栏 **「快捷浮窗 (⌥⌘K)」**、侧边栏底部 **「呼出」** 按钮、顶部菜单栏 `⌘` 图标中的 **「打开快捷浮窗」**。
- **自定义唤起热键**：进入 **「权限与设置 → 全局速查浮窗快捷键」**，点击右侧录制框按下新的修饰键组合即可更新（基于 Carbon `RegisterEventHotKey` 实时重注册）；随时可点击 **「恢复默认 (⌥⌘K)」** 重置。

> 💡 **冲突提示**：如果 `⌥⌘K` 已被其他全局软件占用，启动或修改时主窗口顶部会出现红色提示条，换用 `⌃⌥⌘K` 或 `⌥⌘/` 等组合即可。

### 3.2 自动捕捉前台应用与范围筛选

1. 触发唤起的瞬间（显示浮窗前），KeyMapStudio 会自动捕捉当前位于最前台的外部应用（显示在搜索框右侧的蓝色应用胶囊中）。
2. 在辅助功能已授权时，浮窗即时扫描该应用的全部菜单栏快捷键；如果前台应用恰好是 VS Code、Cursor、Antigravity、iTerm2、Raycast 或 Obsidian 等受支持的开发工具，浮窗还会一并合入其配置文件中的热键。
3. **三段范围切换**：
   - **当前应用**：仅显示刚捕捉到的前台应用菜单及对应开发工具热键。
   - **全部**：汇总当前应用菜单与全系统/全局规则/开发工具快捷键。
   - **系统与工具**：无需辅助功能权限也可随时查询 macOS 系统热键与开发工具配置。
4. **修饰键胶囊与模糊搜索**：
   - 点击右侧 `⌃` `⌥` `⇧` `⌘` 胶囊可组合筛选包含指定修饰键的条目。
   - 搜索框同时匹配命令标题、路径、应用名称、符号写法（如 `⌥⌘K`）和 VS Code 写法（如 `alt+cmd+k`）。

### 3.3 跳转到主窗口快速改键

在浮窗列表中点击任意一条快捷键：
- 浮窗自动收起并唤醒 KeyMapStudio 主窗口；
- 主窗口自动切换到该条目所属的模块（系统快捷键 / 应用与菜单 / 开发工具 / 底层改键），并直接高亮选中该条目；
- 在右侧 **检查器**（或对应视图）中即可立刻点击录制框修改绑定或解决冲突。

---

## 4. 应用菜单快捷键（「应用与菜单」）

此模块对应 macOS 原生应用菜单栏的实时扫描与 `NSUserKeyEquivalents` 持久化覆盖管理。

### 4.1 实时扫描指定应用菜单

1. 在左侧边栏选择 **「应用与菜单」**。
2. 在顶部 **「目标应用」** 下拉菜单中，可选择当前正在运行的任意常规应用，或选择顶部的 **「全局覆盖 (NSGlobalDomain)」**。
3. 选中某个应用后，KeyMapStudio 会通过 `AXUIElement` 自动遍历其菜单栏（最大深度 5 层，自动跳过动态生成的「最近打开 / Open Recent」「书签 / Bookmarks」「历史记录 / History」等子菜单）。需要刷新时可点击 **「重新扫描」**。

### 4.2 修改现有菜单与 `NSUserKeyEquivalents` 层级路径

1. 在中间列表点击任意菜单命令（支持搜索框和 `⌃ ⌥ ⇧ ⌘` 胶囊过滤）。
2. 右侧 **技术详情** 面板会展示其完整菜单路径（例如 `文件 → 导出为 PDF…`）和当前绑定。
3. 在 **「录制新快捷键」** 框中点击一下，输入目标组合键（按 `Esc` 可取消录制）：
   - 必须包含至少一个修饰键（`⌃/⌥/⇧/⌘`），或使用功能键 / 方向键等独立按键（`F1–F20`、`Home`、`End`、`PageUp`、`PageDown`、`Forward Delete`）。
4. 保存时，KeyMapStudio 会将多级菜单路径编码为 Apple 官方要求的 `\u{001B}` 分隔格式写入对应域的 `NSUserKeyEquivalents`，并将该应用的 `bundleID` 注册至 `com.apple.universalaccess` 的 `com.apple.custommenu.apps` 列表（即与“系统设置 → 键盘快捷键 → 应用快捷键”完全同步）。

### 4.3 新增自定义菜单快捷键与多级路径写法

对于没有默认快捷键的菜单项，点击右上角 **「新增菜单快捷键」**：
- **目标应用**：选择具体应用或 **「全局所有应用 (NSGlobalDomain)」**。
- **菜单标题或路径**：
  - 仅填最后一级名称（如 `导出…`）：对该应用内所有同名菜单生效。
  - 使用 `->` 指定完整层级路径（如 `文件->导出为 PDF…` 或 `File->Export As…`）：精确定位到对应子菜单，避免多层子菜单同名冲突。
- **快捷键**：点击录制框按下目标快捷键，点击 **「添加」**。

### 4.4 重启目标应用与一键恢复默认

- **重启生效机制**：macOS AppKit 仅在应用程序启动时加载 `NSUserKeyEquivalents`。因此修改特定应用菜单后，主窗口顶部与检查器中会出现蓝色的 **「需要重启应用以生效」** 提示条，点击 **「立即重启」**（或 **「重启应用以生效」**），KeyMapStudio 会自动优雅退出并重新拉起目标应用，随后自动重扫菜单验证新绑定。
- **一键恢复默认**：选中已修改（带蓝色 **「已修改」** 标签）的菜单项，在右侧检查器点击 **「恢复默认」**，即可删除该项覆盖并在必要时清理空域名；重启目标应用后恢复原始快捷键。

---

## 5. macOS 系统快捷键（「系统快捷键」）

此模块直接管理系统底层的 `~/Library/Preferences/com.apple.symbolichotkeys.plist`（即 `AppleSymbolicHotKeys`）。

### 5.1 分类查看与筛选

KeyMapStudio 内置了 **53 项常用 macOS 系统热键目录**（分为 7 大分类），并会自动合并你本机 plist 中存在的其他扩展系统热键：

| 分类名称 | 包含的典型系统热键 |
| :--- | :--- |
| **聚焦搜索** | 显示聚焦搜索 (`⌘Space`)、显示“访达”搜索窗口 (`⌥⌘Space`) |
| **输入法** | 选择上一个输入法 (`⌃Space`)、选择下一个输入法 (`⌃⌥Space`) |
| **截屏** | 存为文件 / 拷贝到剪贴板 (`⇧⌘3`、`⇧⌘4`、`⌃⇧⌘3`、`⌃⇧⌘4`)、截屏与录制选项 (`⇧⌘5`) |
| **调度中心与空间** | Mission Control、应用程序窗口、显示桌面、左右切换空间、切换到桌面 1–9（含慢动作项） |
| **程序坞与系统** | 自动隐藏程序坞 (`⌥⌘D`)、词典查询、启动台、通知中心、勿扰模式、台前调度、快速备忘录 |
| **键盘与焦点** | 焦点移至菜单栏/程序坞/窗口工具栏/浮动窗口/状态菜单、切换当前应用下一窗口 (`⌘\``)、全键盘控制 |
| **辅助功能** | 缩放开关/放大/缩小、图像平滑、反转颜色、旁白 (VoiceOver)、提高/降低对比度 |

点击顶部横向分类胶囊即可快速定位，或配合搜索框和修饰键过滤检索。

### 5.2 启用 / 禁用、改键与即时生效

1. 在列表选中目标系统快捷键，右侧检查器提供：
   - **启用该快捷键** 开关：可随时停用不常用的系统热键（例如停用 `⌘Space` 给 Raycast / Alfred 让位），而无需更改原键位定义。
   - **录制新快捷键**：点击录制框重新指定组合键。
   - **恢复默认**：随时一键恢复 Apple 出厂默认启用状态与默认键位。
2. **即时刷新原理**：每次保存修改时，KeyMapStudio 写入二进制 Plist 后会自动调用 macOS 系统内置工具：
   ```bash
   /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
   ```
   绝大多数系统热键无需注销或重启电脑即可立即生效。

---

## 6. 交互式 78 键虚拟键盘（「交互式键盘」）

交互式键盘热图把全系统 5 个来源的快捷键投影到实体键位上，方便一眼发现空白可用按键与热点冲突区。

### 6.1 物理键盘联动与鼠标锁定组合

- **物理按键实时高亮**：保持在 **「交互式键盘」** 页面时，按住实体键盘上的 `⌃`、`⌥`、`⇧`、`⌘` 或 `🌐 fn`，画布上的对应修饰键帽会高亮亮起，同时顶部显示 **当前组合前缀**，全键盘实时过滤出只包含该修饰键组合的绑定。松手即恢复全览。
- **鼠标点击锁定修饰键**：若希望解放双手逐个点击查看某套组合（如 `⌥⌘`），可点击顶部工具栏中的 **修饰键胶囊**（`⌃ Ctrl` / `⌥ Opt` / `⇧ Shift` / `⌘ Cmd`）。锁定后胶囊显示小锁图标，物理按压与鼠标锁定会合并计算；点击 **「清除」** 可一键解除锁定。
- **来源筛选下拉框**：支持按 **「全部来源 / 系统 / 应用菜单 / 开发工具 / 重映射」** 单独过滤热图。

### 6.2 五色语义与冲突红点图例

画布顶部提供了完整图例，每个可绑定键帽会根据占用情况渲染底色与小圆点：

| 视觉标识 | 代表含义 | 说明 |
| :--- | :--- | :--- |
| 🔵 **蓝色高亮** | 系统快捷键 | `SymbolicHotKeys` 占用 |
| 🟢 **绿色高亮** | 应用菜单 | 当前扫描应用菜单或全局菜单覆盖 |
| 🟣 **紫色高亮** | 开发工具 | VS Code / Cursor / Antigravity / iTerm2 / Raycast / Obsidian |
| 🟠 **橙色高亮** | 底层改键 / 重映射 | `hidutil` 硬件单键或 `CGEventTap` 组合键规则 |
| 🔴 **右上角红点** | 存在冲突 | 该键位至少有一项绑定参与了全局/同作用域冲突 |
| ⬜ **浅灰边框** | 空闲按键 | 当前筛选条件与修饰键前缀下未被任何已启用规则占用 |

> 注：右上角的 `⏻`（Touch ID / 电源锁定键）为系统硬件保留键，不可绑定（鼠标悬停提示不可编辑）。

### 6.3 键帽点击详情与行内改键

点击画布上任意可绑定键帽后，下半部分 **按键详情面板** 会展示：
- 该键帽的 `VirtualKey` 十六进制与十进制键码（如 `0x28 (40)`）及对应的 `HID Usage`（如 `HID 0x70000000E`）。
- 该键位上的全部匹配快捷键列表：
  - 对于可编辑的条目（系统、应用菜单、支持写入的开发工具），行内直接提供 **「重绑」** 录制框，按新键即时生效。
  - 每行右侧提供 **「定位」** 按钮，点击即可一键跳转到对应的主列表模块查看完整上下文。

---

## 7. 底层键位重映射（「底层改键」）

侧边栏进入 **「底层改键」**，顶部提供两种不同层级的引擎切换：**「硬件单键重映射 (hidutil)」** 与 **「组合键重映射 (CGEventTap)」**。

### 7.1 硬件单键重映射（`hidutil`）

基于 Apple 原生 `/usr/bin/hidutil property --set`，在内核 HID 驱动层进行单键一对一映射，无需应用常驻后台，零延迟、零内存占用。规则保存在 `~/Library/Application Support/KeyMapStudio/hid_rules.json`。

1. **常用预设方案（一键添加并应用）**：
   - **Caps Lock → Escape**：`0x700000039` → `0x700000029`（Vim / 终端高频刚需）
   - **Caps Lock → Left Control**：`0x700000039` → `0x7000000E0`（Emacs / macOS 终端控制键顺手化）
   - **Escape → Caps Lock**：`0x700000029` → `0x700000039`（与上一条配合实现两键互换）
   - **Right ⌘ → Forward Delete**：`0x7000000E7` → `0x70000004C`（为无独立 Delete 键的 MacBook 补齐向前删除）
2. **自定义单键规则**：
   - 点击 **「添加规则」**，自定义规则名称，在左右下拉框选择源按键与目标按键的 HID Usage。
   - 调整开关后，务必点击顶部卡片的 **「立即应用」** 让 `hidutil` 写入内核生效。
3. **开机自动应用（LaunchAgent 持久化）**：
   - 默认情况下 `hidutil` 设置仅在当前登录会话有效，重启 Mac 后会恢复原状。
   - 打开顶部的 **「开机自动应用 (LaunchAgent 持久化)」** 开关，KeyMapStudio 会自动生成 `~/Library/LaunchAgents/com.keymapstudio.hidremap.plist`（标签 `com.keymapstudio.hidremap`，`RunAtLoad = true`），每次登录自动执行已启用的 HID 映射。
4. **重置全部**：点击 **「重置全部 (清空 hidutil)」** 会立即下发 `{"UserKeyMapping":[]}` 还原键盘并同步移除 LaunchAgent。

### 7.2 组合键重映射引擎（`CGEventTap`）

当你需要将“一个组合键”改写为“另一个组合键”（例如 `⌃H → ⌫`），或希望某个按键转发**仅在特定应用内生效**时，请使用此标签页。规则保存在 `~/Library/Application Support/KeyMapStudio/combo_rules.json`。

1. **前提条件**：必须同时授予 **输入监控** 与 **辅助功能** 权限（若未授权，页面顶部会显示橙色引导横幅）。
2. **新增组合键映射**：
   - 点击 **「新增组合键映射」**。
   - **规则名称**：可选，留空将自动生成如 `⌃H → ⌫`。
   - **源组合键 (触发)** & **目标组合键 (输出)**：分别点击录制框按下组合键。
   - **生效应用范围**：选择 **「全局 (所有应用)」** 或在下拉列表中选择某个具体应用（记录其 `bundleID`）。
   - **优先级规则**：当同一源组合键同时存在“指定应用规则”与“全局规则”时，**应用专属规则优先匹配**。
3. **开启引擎与多重安全防线**：
   - 打开引擎卡片右侧的总开关，状态变为绿灯 **「组合键映射引擎运行中 (CGEventTap)」**。
   - **防回环机制**：引擎在修改 `CGEvent` 的键码与修饰键标志时，会写入魔术标签 `.eventSourceUserData = 0x4B4D5354`（`'KMST'`），拦截回调遇到该标记会直接放行，彻底杜绝链式递归死循环。
   - **录制自动暂停**：在 KeyMapStudio 内点击任何快捷键录制框时，引擎自动进入暂停状态，确保录制新键位时不会被旧映射劫持。
   - **超时自愈**：若系统因高负载临时禁用 Tap（`tapDisabledByTimeout`），回调会自动重新激活。
   - **菜单栏急停保护**：任何时候都可以点击顶部菜单栏 KeyMapStudio 图标，选择 **「紧急停止所有组合键改键」** 或 **「停止组合键重映射引擎」** 一键切断转发。

---

## 8. 开发工具配置聚合（「开发工具」）

侧边栏进入 **「开发工具」**，顶部状态卡片会展示各工具的安装状态、配置文件是否存在、快捷键总数与本地路径（点击 **「在访达中显示」** 可直达文件）。

| 工具 | Bundle ID | 配置文件路径 | 权限 | 特性说明 |
| :--- | :--- | :--- | :---: | :--- |
| **VS Code** | `com.microsoft.VSCode` | `~/Library/Application Support/Code/User/keybindings.json` | 读写 | 支持 JSONC、`-command`、`when` 上下文 |
| **Cursor** | `com.todesktop.230313mzl4w4u92` | `~/Library/Application Support/Cursor/User/keybindings.json` | 读写 | 支持 JSONC、`-command`、`when` 上下文 |
| **Antigravity** | `com.google.antigravity` | `~/Library/Application Support/Antigravity/User/keybindings.json` | 读写 | 支持 JSONC、`-command`、`when` 上下文 |
| **iTerm2** | `com.googlecode.iterm2` | `~/Library/Preferences/com.googlecode.iterm2.plist` | 读写 | 解析与编辑 `GlobalKeyMap` 及首个 Profile `Keyboard Map` |
| **Raycast** | `com.raycast.macos` | `~/Library/Preferences/com.raycast.macos.plist` | **只读** | 解析 `raycastGlobalHotkey` 与命令热键并参与全局冲突检测 |
| **Obsidian** | `md.obsidian` | `~/Library/Application Support/obsidian/obsidian.json` → `<Vault>/.obsidian/hotkeys.json` | 读写 | 自动发现全部本地 Vault 仓库并按库名标注读写 |

### 8.1 VS Code / Cursor / Antigravity 说明

- **JSONC 兼容**：内置 `JSONCParser` 能够正确剥离单行 `//` 注释、块级 `/* ... */` 注释、UTF-8 BOM 与尾随逗号，正常读取包含手写注释的 `keybindings.json`。
  > ⚠️ **注意**：当你通过 KeyMapStudio 点击 **「修改」**、**「新增快捷键」** 或移除条目写回 `keybindings.json` 时，会使用标准格式化 JSON 重新序列化写入（原有的 `//` 手写注释不会被保留）。如 `keybindings.json` 中有重要手写注释，建议先在「快照与备份」备份或自行留档。
- **`-command` 禁用规则识别**：如果某条命令以 `-` 开头（例如 `-workbench.action.closeWindow`），界面会以红色 **「已禁用 (-)」** 胶囊清晰标出，并在冲突检测时将其视为非激活绑定；在检查器或冲突中心切换其启用开关时，会自动在命令前增删 `-` 前缀。
- **`when` 上下文过滤**：列表搜索框同时检索命令 ID 与 `when` 表达式（如 `editorTextFocus`），新建快捷键时也可填写可选的 `when` 条件。

### 8.2 iTerm2、Raycast 与 Obsidian 细节

- **iTerm2**：自动解码 `0x<char>-0x<mod>`（及可选第三段虚拟键码）为可视化按键组合，并把 `Action` 数字代码翻译为可读动作名（如 `Next Tab`、`Split Vertically`、`Send Escape Sequence` 等）。
- **Raycast（只读标记）**：为了不干扰 Raycast 自身的实时偏好数据库与加密扩展状态，Raycast 适配器以 **只读** 模式读取全局唤起键与命令热键。你可以在「冲突中心」和「交互式键盘」中发现它与系统或其他软件的撞车，如需更改请在 Raycast 偏好设置中调整。
- **Obsidian 多 Vault 自动发现**：自动读取 `obsidian.json` 中登记的所有仓库路径并扫描各自的 `.obsidian/hotkeys.json`；当拥有多个 Vault 时，条目副标题会显示 `Vault: <仓库名> · <命令>`，修改时会写回对应 Vault 的配置文件。

---

## 9. 跨层全局冲突中心（「冲突中心」）

侧边栏 **「冲突中心」** 实时聚合来自全部 5 个层级（已启用的规则）的快捷键，按规范化按键签名 `canonicalKey`（`mod:<标准修饰键掩码>:vk:<虚拟键码>`）进行碰撞分析。

### 9.1 三级冲突判定原理

| 级别 | 颜色 | 触发条件 | 典型场景举例 |
| :--- | :---: | :--- | :--- |
| **高危 (Critical)** | 🔴 红色 | 同作用域内存在直接抢占，必现其一失效 | 1. 两个及以上全局热键共用了 `⌥⌘Space`（如系统“访达搜索”与 Raycast 全局热键）<br>2. **同一个应用**内存在两个菜单项绑定了相同快捷键<br>3. **同一个开发工具**在**相同 `when` 条件**下（或均无 `when`）重复绑定了同一按键 |
| **警告 (Warning)** | 🟠 橙色 | 全局热键与局部应用/工具热键共用，触发时可能被全局拦截遮蔽 | 系统快捷键（如 `⌃Space` 切换输入法）与 VS Code 里的自动补全快捷键重合 |
| **提示 (Info)** | 🔵 蓝色 | 同一开发工具在**不同 `when` 上下文**下复用同一快捷键 | VS Code 中 `editorTextFocus` 与 `terminalFocus` 分别绑定了同一按键（通常属于有意设计，仅供参考） |

> **零误报设计**：不同应用程序之间（如 Safari 与访达各自菜单里都有 `⌘W` 或 `⌘,`）拥有相互隔离的聚焦作用域，**不会**被误报为冲突。

### 9.2 一键解决冲突

在 **「冲突中心」** 展开任意冲突卡片（默认自动展开前 3 项重要冲突），会并排显示所有参与撞车的条目卡片，你可以直接在卡片内执行：
- **修改快捷键**：点击录制框直接为其中一项重绑新快捷键。
- **禁用 / 启用**：快速停用不需要的系统快捷键、开发工具绑定或改键规则。
- **恢复默认**：将已自定义的条目一键还原为初始状态。

处理完毕后，卡片会自动消退，侧边栏与菜单栏右上角的红色冲突徽标也会实时更新。

---

## 10. 配置快照备份与换机迁移（「快照与备份」）

### 10.1 存储位置与包含内容

所有本地快照均以结构化 JSON 文件形式存储在：

```text
~/Library/Application Support/KeyMapStudio/snapshots/<UUID>.json
```

每份快照（`schemaVersion: 1`）完整囊括以下 5 层配置：
1. `symbolicHotkeys`：全部系统快捷键启用状态与键码参数
2. `appMenuOverrides`：`NSGlobalDomain` 与所有定制应用的 `NSUserKeyEquivalents`
3. `hidRules`：硬件单键 HID 映射规则列表
4. `comboRules`：组合键 `CGEventTap` 映射规则列表
5. `devToolOverrides`：VS Code / Cursor / Antigravity / iTerm2 / Raycast / Obsidian 导出的绑定记录

### 10.2 创建快照、回滚与跨机迁移

- **创建快照**：点击右上角 **「立即创建快照」**，输入易懂的命名（默认按当前时间生成 `基线快照 yyyy-MM-dd HH:mm`），卡片底部会以五色胶囊显示各层记录条数。
- **安全回滚**：点击某个快照卡片上的 **「恢复此快照」**，在弹出的确认对话框点击确认后，KeyMapStudio 会自动还原系统快捷键（并执行 `activateSettings -u`）、重写 `NSUserKeyEquivalents` 与 `com.custommenu.apps`、重新应用 `hidutil`、覆盖 `combo_rules.json` 并导入所有支持写入的开发工具配置（注：只读的 Raycast 记录不自动写回；已修改菜单的应用需重启生效）。
- **换机迁移（JSON 导入 / 导出）**：
  - 点击顶部 **「导出 JSON」** 可将当前实时配置打包导出（默认文件名 `KeyMapStudio-yyyyMMdd-HHmmss.json`），或点击具体快照卡片的 **「导出」** 按钮保存为独立 JSON 文件。
  - 在新 Mac 上打开 KeyMapStudio，点击 **「导入 JSON」** 选择备份文件，导入后会出现在快照列表中；确认后点击 **「恢复此快照」** 即可一键复刻全部快捷键环境。
- **版本对比提示**：`KeyMapCore` 内置了 `SnapshotManager.diff(from:to:)` 差异汇总模型（可在单元测试与核心库中统计 5 层各自变更条数与明细）；如需在命令行快速对比两份导出的快照 JSON，可使用：
  ```bash
  diff -u <(jq -S . old-snapshot.json) <(jq -S . new-snapshot.json)
  ```

---

## 11. 常见问题与完全恢复 / 卸载指南

### 11.1 常见问题 FAQ

- **Q1：修改了某个 App 的菜单快捷键，为什么在那个 App 里按了没反应？**
  - macOS 仅在应用冷启动时读取 `NSUserKeyEquivalents`。请点击 KeyMapStudio 顶部提示栏的 **「重启应用以生效」** 或手动 `⌘Q` 彻底退出该 App 后再重新打开；同时检查菜单名称拼写或层级路径 `父菜单->子菜单` 是否与目标应用当前语言界面完全一致（注意中文/英文省略号 `…` 与 `...` 的区别）。
- **Q2：按 `⌥⌘K` 没法唤出极速浮窗，或者顶部报错提示注册失败？**
  - 说明 `⌥⌘K` 已被系统或其他常驻软件抢占。请前往 **「权限与设置 → 全局速查浮窗快捷键」** 重新录制一个不冲突的全局热键，或使用菜单栏图标呼出。
- **Q3：组合键重映射开关打开就自动弹回，提示无法启动？**
  - 请检查 **「权限与设置」** 中 **「输入监控」** 与 **「辅助功能」** 是否均已显示为绿色 **「已授权」**。如果刚在系统设置勾选，建议完全退出 KeyMapStudio 后重新打开再试。
- **Q4：为什么 Raycast 在「开发工具」页面显示“只读”？**
  - Raycast 将热键和扩展配置存放在活跃管理的 Preferences 中，直接外部篡改容易被其内存缓存覆盖或引发同步异常，因此 KeyMapStudio 对其采用安全的只读解析模式，确保冲突检测覆盖完整而不破坏配置。
- **Q5：在「开发工具」改写 VS Code / Cursor 快捷键后，原来手写的注释怎么没了？**
  - KeyMapStudio 读取时完全兼容 JSONC 注释与尾随逗号，但写回时采用标准 JSON 格式化输出。若习惯在 `keybindings.json` 中保留大量注释，建议提前使用快照备份或以注释备份文件留存。

### 11.2 完全恢复默认与干净卸载指南

无论你只是想排查恢复键盘状态，还是准备彻底卸载 KeyMapStudio，都可以按以下步骤操作（**先还原配置，再删除应用**）：

1. **停用并清空底层改键**：
   - 在软件内进入 **「底层改键」**：
     - 切换到 **「组合键重映射 (CGEventTap)」** 关闭总开关；
     - 切换到 **「硬件单键重映射 (hidutil)」** 关闭 **「开机自动应用」** 并点击 **「重置全部 (清空 hidutil)」**。
   - 或者在「终端」执行以下命令立即强制还原：
     ```bash
     # 1) 立即清空内核 HID 硬件映射（秒级恢复所有物理按键）
     /usr/bin/hidutil property --set '{"UserKeyMapping":[]}'

     # 2) 卸载并删除 KeyMapStudio 安装的 LaunchAgent 开机自启项
     launchctl unload ~/Library/LaunchAgents/com.keymapstudio.hidremap.plist 2>/dev/null || true
     rm -f ~/Library/LaunchAgents/com.keymapstudio.hidremap.plist
     ```
2. **清除应用菜单覆盖（`NSUserKeyEquivalents`）**：
   - 在 **「应用与菜单」** 中逐个点击 **「恢复默认」**；或使用终端批量查看并清除：
     ```bash
     # 查看哪些应用配置过自定义菜单快捷键
     defaults read com.apple.universalaccess com.apple.custommenu.apps

     # 清除全局菜单快捷键覆盖（如有）
     defaults delete NSGlobalDomain NSUserKeyEquivalents 2>/dev/null || true

     # 清除指定应用的菜单快捷键覆盖（将 <bundleID> 替换为目标应用 ID，例如 com.apple.Safari）
     defaults delete <bundleID> NSUserKeyEquivalents 2>/dev/null || true
     ```
   - 清理后重启对应应用即可恢复原厂菜单快捷键。
3. **恢复系统快捷键（如曾改写）**：
   - 推荐在卸载前，于 **「系统快捷键」** 选中带 **「已修改」** 标记的条目点击 **「恢复默认」**，或恢复最初创建的基线快照。
   - 如需在终端刷新系统快捷键缓存，可执行：
     ```bash
     /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
     ```
4. **移除应用本体、本地规则与快照数据**：
   ```bash
   # 删除本地快照、hid_rules.json、combo_rules.json 等应用数据
   rm -rf ~/Library/Application\ Support/KeyMapStudio

   # 删除浮窗快捷键等偏好设置
   defaults delete com.keymapstudio.app 2>/dev/null || true

   # 删除应用程序本体
   rm -rf /Applications/KeyMapStudio.app
   ```
5. **（可选）清理系统隐私授权记录**：前往 **系统设置 → 隐私与安全性**，在 **「辅助功能」** 与 **「输入监控」** 中选中 KeyMapStudio 后点击 `-` 号移除条目即可彻底不留痕迹。
