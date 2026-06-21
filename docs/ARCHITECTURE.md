# Terminal Notifier — 技术架构设计

> 本文档记录 Terminal Notifier 的当前技术架构与关键实现取舍。

---

## 1. 项目结构

```
TerminalNotifier/
├── TerminalNotifier/
│   ├── Info.plist
│   ├── App/
│   │   ├── main.swift                         # 应用入口（手动 NSApplication 启动）
│   │   ├── AppDelegate.swift                  # 组装所有模块
│   │   └── Constants.swift                    # 全局常量
│   ├── MenuBar/
│   │   └── StatusBarController.swift          # 菜单栏猫图标（normal/notifying/paused 三态各一张 PNG）+ 下拉菜单
│   ├── Detection/
│   │   ├── TerminalContentMonitor.swift       # lsappinfo 轮询 Terminal Dock badge
│   │   ├── ClaudeCodeMonitor.swift            # 轮询 Claude Code hook 投放的事件标记文件
│   │   └── TerminalScreenLocator.swift        # 定位 Terminal 所在屏幕
│   ├── Integration/
│   │   └── ClaudeHookManager.swift            # 安全合并/移除 ~/.claude/settings.json 的 hook
│   ├── Notification/
│   │   └── NotificationStateMachine.swift     # 通知生命周期状态机
│   ├── Overlay/
│   │   ├── OverlayWindowController.swift      # 透明悬浮窗管理
│   │   ├── OverlayContentView.swift           # 主容器视图（宠物 + 气泡）
│   │   ├── PetSpriteView.swift                # 像素猫渲染（加载 PetCat.png，最近邻绘制）
│   │   └── SpeechBubbleView.swift             # 漫画气泡框
│   ├── Animation/
│   │   ├── DropBounceAnimator.swift           # 掉落 + 弹跳动画
│   │   ├── JumpBackAnimator.swift             # 跳回菜单栏动画
│   │   └── SpriteFramePlayer.swift            # 序列帧播放器
│   ├── Messages/
│   │   ├── MessageProvider.swift              # 分类随机选句
│   │   ├── messages_zh.json                   # 中文预设
│   │   └── messages_en.json                   # 英文预设
│   ├── Settings/
│   │   ├── SettingsWindowController.swift      # 设置窗口壳（AppKit）
│   │   ├── SettingsView.swift                 # 设置界面（SwiftUI）
│   │   └── PreferencesManager.swift           # UserDefaults 读写
│   ├── History/
│   │   └── NotificationHistoryManager.swift   # 通知历史存储
│   ├── Sound/
│   │   └── SoundManager.swift                 # 音效播放
│   └── Resources/
│       ├── PetCat.png                         # 悬浮窗大猫素材（16×16 像素图，@2x）
│       ├── MenuBarCat.png                     # 菜单栏小猫·normal（11×11，@2x）
│       ├── MenuBarCatNotifying.png            # 菜单栏小猫·notifying（红）
│       └── MenuBarCatPaused.png               # 菜单栏小猫·paused（灰）
├── build.sh                                   # 编译 + TerminalNotifierDev 证书签名 + 安装到 /Applications
└── README.md
```

---

## 2. 关键技术决策

### 2.1 终端变化检测：lsappinfo 读取 Dock Badge

经过多轮迭代最终采用的方案：

1. **lsappinfo "Terminal"**：应用名不匹配，返回空
2. **AX API 读 AXStatusLabel**：Dock 中 Terminal 的 item 不支持该属性（error -25212）
3. **AX API 读 AXTextArea**：Terminal AX 渲染值不断变化 → 频繁误触发，已废弃
4. **lsappinfo com.apple.Terminal**（最终方案）：用 Bundle ID 读取 Dock badge

**工作原理：**
- 每 1 秒执行 `lsappinfo info -only StatusLabel com.apple.Terminal`
- 解析输出中的 `"label"="N"`，N > 0 表示有 badge
- 当 Terminal **不是**最前面应用 + badge 出现 → 触发提醒
- 首次启动捕获当前 badge 值作为基线，避免误触发已有 badge
- **无需辅助功能权限**

### 2.2 悬浮窗口：NSWindow level 101 + visibleFrame

- `NSWindow.Level.screenSaver`（level 101）可覆盖包括全屏应用在内的所有窗口
- `collectionBehavior: [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`
- 窗口 rect 使用 `screen.visibleFrame`（避开菜单栏区域），否则菜单栏猫咪图标无法点击
- 无边框 + 透明背景，`hitTest` 配合 `mouseDown` 实现：点击猫/气泡 → 关闭，点击空白 → 穿透

### 2.3 动画：CAKeyframeAnimation + Timer 帧播放

- 掉落/弹跳/跳回的位移动画用 `CAKeyframeAnimation`（阻尼振荡数学模型）
- 序列帧播放用 `Timer`（macOS 13 不支持 CADisplayLink，CADisplayLink 是 macOS 14+）
- 像素风 8 FPS 足够流畅

### 2.4 权限需求

- **无特殊权限需求**。Badge 检测通过 `lsappinfo` 命令读取，无需辅助功能权限或屏幕录制权限
- **App Sandbox**：关闭。`Process` 执行 CLI 命令 + `CGWindowListCopyWindowInfo` 需要非沙盒环境
- **代码签名**：自签证书 `TerminalNotifierDev`（`codesign --sign "TerminalNotifierDev"`），保持 TCC 权限跨重编译稳定（如未来需要其他权限）

### 2.5 Claude Code 集成（第二触发源）

独立于 badge 的语义化信号源：

- **hook → App 通道**：`ClaudeHookManager` 在 `~/.claude/settings.json` 注册两条 command hook——`Notification`（`matcher: permission_prompt`）和 `Stop`。hook 经 `/bin/sh` 用 `mktemp` 在 `~/Library/Application Support/TerminalNotifier/claude-events/` 投放标记文件（`<type>.XXXXXX`；macOS BSD `date` 无 `%N`，故用 mktemp 保唯一）。
- **消费**：`ClaudeCodeMonitor` 每秒轮询该目录，解析类型→`MessageProvider.Category`→删文件→Terminal 非前台则回调 delegate。
- **安全合并**：`install()/uninstall()` 用 `JSONSerialization` 只增删带 `# terminal-notifier-hook` 标记的 entry，幂等，写前时间戳备份。**权衡**：重写会规整文件格式/键序。
- **状态机**：新增 `.claudeTrigger(category)`，复用现有掉落/气泡/跳回/冷却；Claude 提醒不参与「N 条」合并，也不做 2 分钟 longWait 升级。
- **开关**：`PreferencesManager.claudeCodeEnabled`（默认关）；`AppDelegate` 观察其变化触发 install/uninstall + 启停监控，启动时若开启则幂等自愈。
- **限制**：Esc 中断无对应 hook 不可检测；不处理 idle；前台门控仅识别 Terminal.app。

---

## 3. 模块职责与接口

### 3.1 App / main.swift + AppDelegate

入口点采用手动 `main.swift` 而非 `@main` 属性（`@main` 在手动 swiftc 编译的 .app bundle 中不可靠，`applicationDidFinishLaunching` 不会被调用）。

```swift
// main.swift — 入口点
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

// AppDelegate.swift — 组装所有模块
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!
    private var contentMonitor: TerminalContentMonitor!
    private var stateMachine: NotificationStateMachine!
    private var overlayController: OverlayWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. 初始化 OverlayWindowController
        // 2. 初始化 StatusBarController
        // 3. 初始化 TerminalContentMonitor
        // 4. 初始化 StateMachine
        // 5. 设置回调链
        // 6. 启动内容监测
    }
}

// Info.plist 关键配置
// LSUIElement = YES → 无 Dock 图标（纯菜单栏应用）
// LSMinimumSystemVersion = 13.0
```

### 3.2 MenuBar / StatusBarController

管理菜单栏图标和下拉菜单。

```swift
class StatusBarController {
    private let statusItem: NSStatusItem
    private let menu: NSMenu

    init(preferences: PreferencesManager,
         onSettingsClicked: @escaping () -> Void,
         onPauseToggled: @escaping (Bool) -> Void,
         onHistoryClicked: @escaping () -> Void)

    func updateIcon(state: MenuBarIconState)
}

enum MenuBarIconState {
    case normal      // 静止像素猫
    case notifying   // 猫已弹出（菜单栏图标变暗）
    case paused      // 暂停状态（灰色图标）
}
```

**菜单项：**
- "设置..." → 打开设置窗口
- "暂停提醒" / "恢复提醒" → toggle
- "通知历史" → 打开历史面板
- 分隔线
- "退出 Terminal Notifier"

### 3.3 Detection / TerminalContentMonitor

核心检测模块。通过 `lsappinfo` CLI 轮询 Terminal.app 的 Dock badge。

```swift
protocol TerminalContentMonitorDelegate: AnyObject {
    func terminalContentDidChange(_ monitor: TerminalContentMonitor)
}

class TerminalContentMonitor {
    weak var delegate: TerminalContentMonitorDelegate?
    private var timer: Timer?
    private var lastBadgeLabel: String?

    func startMonitoring()
    func stopMonitoring()
    private func checkBadge()
    private func isTerminalFrontmost() -> Bool
    private func readBadge() -> String?
}
```

**工作原理：**
1. 启动时捕获当前 badge 值作为基线（避免对已有 badge 误触发）
2. 每秒执行 `lsappinfo info -only StatusLabel com.apple.Terminal`
3. 解析 `"label"="N"` 获取 badge 数值
4. Terminal 前台 → 更新基线，不触发（用户在看）
5. Terminal 后台 + badge 从 nil/0 变为非零 → 触发 delegate

> 之前尝试的 AX 文本内容监控因 Terminal AX 渲染值不断变化导致频繁误触发，已废弃。

### 3.4 Detection / TerminalScreenLocator

定位 Terminal.app 窗口所在屏幕。

```swift
struct TerminalScreenLocator {
    static func locateScreen() -> NSScreen
}
```

**实现：** `CGWindowListCopyWindowInfo` 查找 owner name 为 "Terminal" 的窗口 → 取 bounds → 匹配 `NSScreen.screens`。找不到则回退到主屏幕。

### 3.5 Notification / NotificationStateMachine

管理通知的完整生命周期。

```swift
protocol NotificationStateMachineDelegate: AnyObject {
    func stateMachine(_ sm: NotificationStateMachine, transitionedTo state: NotificationState)
}

enum NotificationState {
    case idle
    case detected(count: Int)
    case showing(count: Int)
    case animatingOut
}

enum NotificationEvent {
    case badgeDetected
    case badgeCleared
    case dropAnimationCompleted
    case userDismissed
    case jumpBackCompleted
    case cooldownExpired
    case longWaitElapsed
}

class NotificationStateMachine {
    weak var delegate: NotificationStateMachineDelegate?
    private(set) var currentState: NotificationState = .idle
    private var pendingCount: Int = 0
    private var badgeFirstDetectedAt: Date?

    func handleEvent(_ event: NotificationEvent)
}
```

**状态转换图：**
```
                    badgeDetected
        idle ──────────────────────► detected(1)
         ▲                                │
         │                                │ dropAnimationCompleted
         │                                ▼
         │    jumpBackCompleted     showing(N) ◄─── badgeDetected (count++)
         │◄──── animatingOut ◄──────────────
         │         userDismissed
         │
         │◄──── cooldown (10s 后才允许下次触发)
```

**合并逻辑：** `.showing(count)` 状态下再收到 `badgeDetected` → `count += 1` → 气泡更新为 "你有 {count} 条终端通知"。

**长时间未响应：** 进入 `.showing` 时启动 `longWaitTimer`，`badgeFirstDetectedAt` 记录首次检测时间。badge 持续存在满 2 分钟仍未被关闭 → 触发 `.longWaitElapsed`，主动将气泡话语类别切换为 `long_wait`（用户点关闭则定时器取消）。

### 3.6 Overlay / OverlayWindowController

管理透明悬浮窗口。

```swift
class OverlayWindowController {
    private var window: NSWindow?
    private var contentView: OverlayContentView?

    func show(on screen: NSScreen,
              message: String,
              onDismiss: @escaping () -> Void)

    func updateMessage(_ message: String)
    func dismiss()
    func close()
}
```

**窗口配置：**
```swift
let window = NSWindow(
    contentRect: screen.frame,
    styleMask: .borderless,
    backing: .buffered,
    defer: false
)
window.isOpaque = false
window.backgroundColor = .clear
window.hasShadow = false
window.level = .screenSaver
window.collectionBehavior = [
    .canJoinAllSpaces,
    .fullScreenAuxiliary,
    .stationary,
    .ignoresCycle
]
window.isReleasedWhenClosed = false
```

**键盘事件：**
```swift
class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc
            // 触发 dismiss
        }
    }
}
```

### 3.7 Overlay / PetSpriteView

```swift
class PetSpriteView: NSView {
    var spriteSheet: NSImage?
    var frameSize: NSSize = NSSize(width: 320, height: 320)
    var currentFrame: Int = 0

    func setAnimation(_ animation: PetAnimation)
}

enum PetAnimation {
    case idle
    case drop
    case land
    case talk
    case jumpBack
}
```

### 3.8 Overlay / SpeechBubbleView

```swift
class SpeechBubbleView: NSView {
    var text: String = ""
    var tailDirection: TailDirection = .bottom

    override func draw(_ dirtyRect: NSRect) {
        // 1. 圆角矩形气泡体（白色填充，黑色描边，像素风粗边框）
        // 2. 三角形尾巴指向猫
        // 3. 文字（像素风字体）
    }
}
```

### 3.9 Animation / DropBounceAnimator

```swift
class DropBounceAnimator {
    func animate(layer: CALayer, from startY: CGFloat, to endY: CGFloat,
                 completion: @escaping () -> Void)
}
```

**阻尼振荡公式：**
```
y(t) = endY + (startY - endY) × e^(-damping × t) × cos(2π × frequency × t)

damping  = 4.0   // 衰减速度
frequency = 2.5  // 弹跳频率
duration = 1.2s  // 总时长
```

生成 60+ 关键帧 → `CAKeyframeAnimation(keyPath: "position.y")`。

### 3.10 Animation / JumpBackAnimator

```swift
class JumpBackAnimator {
    func animate(layer: CALayer, from currentPos: CGPoint, to menuBarPos: CGPoint,
                 completion: @escaping () -> Void)
}
```

`CAKeyframeAnimation(keyPath: "position")`，抛物线弧路径，0.6s，配合缩小动画。

### 3.11 Animation / SpriteFramePlayer

```swift
class SpriteFramePlayer {
    private var timer: Timer?
    private let fps: Double = 8.0
    var onFrameUpdate: ((Int) -> Void)?

    func play(frameCount: Int, loop: Bool)
    func stop()
}
```

### 3.12 Messages / MessageProvider

```swift
struct MessageProvider {
    enum Category: String, Codable {
        case newNotification = "new_notification"
        case longWait = "long_wait"
        case merged = "merged"
    }

    func randomMessage(category: Category, locale: String) -> String
    func mergedMessage(count: Int, locale: String) -> String
}
```

**messages_zh.json：**
```json
{
  "new_notification": [
    "喵~ 终端在叫你！快去看看吧",
    "有消息啦！终端那边需要你",
    "嘿！终端亮红灯了，去瞧瞧？",
    "终端有动静了，别忘了哦~",
    "喵呜！你的终端在等你回复呢"
  ],
  "long_wait": [
    "喂喂喂，终端等你好久了！",
    "终端都急了...快去看看吧！",
    "你是不是忘了终端还开着？",
    "已经过了好一会儿了，终端还在等你...",
    "再不去看，终端要生气了喵！"
  ],
  "merged": "你有 {count} 条终端通知"
}
```

**messages_en.json：**
```json
{
  "new_notification": [
    "Meow~ Terminal is calling! Go check it out!",
    "Hey! Terminal's got something for you!",
    "Your terminal lit up — take a look?",
    "Something happened in the terminal, don't forget~",
    "Meow! Your terminal is waiting for a reply!"
  ],
  "long_wait": [
    "Hey hey hey, terminal's been waiting forever!",
    "Terminal is getting impatient... go check!",
    "Did you forget your terminal is still open?",
    "It's been a while... terminal is still waiting...",
    "If you don't go check, terminal's gonna be mad! Meow!"
  ],
  "merged": "You have {count} terminal notifications"
}
```

### 3.13 Settings / PreferencesManager

```swift
class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()

    @AppStorage("enabled")              var enabled: Bool = true
    @AppStorage("soundEnabled")         var soundEnabled: Bool = true
    @AppStorage("cooldownSeconds")      var cooldownSeconds: Int = 10
    @AppStorage("dndEnabled")           var dndEnabled: Bool = false
    @AppStorage("dndStartHour")         var dndStartHour: Int = 22
    @AppStorage("dndEndHour")           var dndEndHour: Int = 8
    @AppStorage("launchAtLogin")        var launchAtLogin: Bool = false
    @AppStorage("language")             var language: String = "system"
    @AppStorage("switchToTerminal")     var switchToTerminal: Bool = false
    @AppStorage("selectedPet")          var selectedPet: String = "pixel_cat"

    var isInDNDPeriod: Bool { get }
    var resolvedLocale: String { get }                  // = resolveLocale(language)
    static func resolveLocale(_ language: String) -> String  // 设置界面与通知话语共用
}
```

### 3.14 Settings / SettingsView (SwiftUI)

```swift
struct SettingsView: View {
    @ObservedObject var preferences: PreferencesManager

    var body: some View {
        TabView {
            GeneralSettingsTab(preferences: preferences)
                .tabItem { Label("通用", systemImage: "gear") }
            NotificationSettingsTab(preferences: preferences)
                .tabItem { Label("通知", systemImage: "bell") }
        }
        .frame(width: 450, height: 350)
    }
}
```

**通用 Tab：** 启用/禁用、开机自启、语言选择、宠物选择（预留）
**通知 Tab：** 声音开关、冷却时间下拉（5/10/15/30/60/120 秒）、免打扰时段、消失后跳转终端

### 3.15 Settings / SettingsWindowController

```swift
class SettingsWindowController {
    private var window: NSWindow?

    func showSettings(preferences: PreferencesManager) {
        if window == nil {
            let settingsView = SettingsView(preferences: preferences)
            let hostingController = NSHostingController(rootView: settingsView)
            window = NSWindow(contentViewController: hostingController)
            window?.title = "Terminal Notifier Settings"
            window?.styleMask = [.titled, .closable]
            window?.setContentSize(NSSize(width: 450, height: 350))
        }
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
```

### 3.16 History / NotificationHistoryManager

```swift
struct NotificationRecord: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let badgeLabel: String
    let message: String
    let category: MessageProvider.Category
}

class NotificationHistoryManager {
    private let maxRecords = 100
    private let storageKey = "notificationHistory"

    func addRecord(_ record: NotificationRecord)
    func getRecords() -> [NotificationRecord]
    func clearHistory()
}
```

存储：UserDefaults + JSON 编码，最多 100 条。

### 3.17 Sound / SoundManager

```swift
class SoundManager {
    private var sound: NSSound?

    func playNotificationSound() {
        guard PreferencesManager.shared.soundEnabled else { return }
        sound = NSSound(named: "Glass")   // 系统音；nil 时回退 NSSound.beep()
        sound?.play()
    }
}
```

---

## 4. 数据流

```
┌─────────────────────────────────────────────────────────────────────┐
│                          AppDelegate                                 │
│  ┌───────────────┐ ┌──────────────┐ ┌──────────────────────┐     │
│  │ContentMonitor  │→│StateMachine  │→│OverlayWindowController│   │
│  │(lsappinfo poll)│ │              │ │                      │     │
│  └──────────┘     │ idle         │     │  PetSpriteView       │     │
│       │            │  ↓ detected  │     │  SpeechBubbleView    │     │
│       │            │  ↓ animIn    │     │  DropBounceAnimator  │     │
│       │            │  ↓ showing   │     │  JumpBackAnimator    │     │
│       │            │  ↓ animOut   │     └──────────┬───────────┘     │
│       │            │  ↓ idle      │                │                 │
│       │            └──────────────┘                │                 │
│       │                   │                        │                 │
│       ▼                   ▼                        ▼                 │
│  ┌──────────┐     ┌──────────────┐     ┌──────────────────────┐     │
│  │Terminal   │     │Message       │     │Sound                 │     │
│  │ScreenLoc. │     │Provider      │     │Manager               │     │
│  └──────────┘     └──────────────┘     └──────────────────────┘     │
│                                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐       │
│  │StatusBar     │  │Settings      │  │NotificationHistory   │       │
│  │Controller    │  │WindowCtrl    │  │Manager               │       │
│  └──────────────┘  └──────────────┘  └──────────────────────┘       │
└─────────────────────────────────────────────────────────────────────┘
```

**主流程（10 步）：**
1. `TerminalContentMonitor` 每秒执行 `lsappinfo`，检测到 Terminal 后台 badge 出现 → 通知 `AppDelegate`
2. `AppDelegate` 检查 `PreferencesManager`（是否启用、是否冷却中、是否免打扰）
3. 通过 → 向 `StateMachine` 发送 `.badgeDetected`
4. `StateMachine` 转为 `.detected`
5. `AppDelegate` 调 `TerminalScreenLocator` 定位屏幕
6. `AppDelegate` 调 `MessageProvider` 获取随机话语
7. `OverlayWindowController.show()` → 创建窗口 → 掉落动画 → 显示气泡
8. `SoundManager` 播放音效，`NotificationHistoryManager` 记录
9. 用户点击/Esc → `.userDismissed` → `.animatingOut` → 跳回动画
10. 动画完成 → `.idle`，可选激活 Terminal.app，冷却计时 10 秒

---

## 5. Sprite Sheet 规格

| 动作 | 文件 | 帧数 | 单帧尺寸 | Sheet 布局 | 说明 |
|------|------|------|----------|-----------|------|
| idle | cat_idle.png | 1 | 18×18 | 单帧 | 菜单栏图标 |
| drop | cat_drop.png | 4 | 320×320 | 1×4 横排 | 掉落姿势变化 |
| land | cat_land.png | 3 | 320×320 | 1×3 横排 | 落地缓冲 |
| talk | cat_talk.png | 2 | 320×320 | 1×2 横排 | 嘴巴开合 |
| jump | cat_jump.png | 4 | 320×320 | 1×4 横排 | 跳回姿势 |

**第一版（占位方案已废弃）：** 曾用代码绘制的字符网格占位像素猫跑通；现已替换为 PNG 素材（`PetCat.png` / `MenuBarCat.png`），运行时由 `Bundle.main` 加载并最近邻渲染。

---

## 6. 构建与分发

**Xcode 项目配置：**
- Deployment Target: macOS 13.0
- Signing: 自签证书 `TerminalNotifierDev`（`codesign --force --deep --sign "TerminalNotifierDev"`），保持签名一致性
- App Sandbox: **关闭**
- Info.plist: `LSUIElement = YES`
- 编译后自动安装到 `/Applications/`，`build.sh` 一步完成 编译→签名→安装

**开机自启：**
```swift
import ServiceManagement

func setLaunchAtLogin(_ enabled: Bool) {
    let service = SMAppService.mainApp
    do {
        if enabled { try service.register() }
        else { try service.unregister() }
    } catch {
        print("Launch at login error: \(error)")
    }
}
```

**GitHub Release 产物：**
- `TerminalNotifier.app`（签名 .app bundle）
- `TerminalNotifier.zip`（压缩包）
- `TerminalNotifier.dmg`（可选）

---

## 7. 实施阶段

### Phase 1：骨架 + Badge 检测 ✅
- 创建 `main.swift` 手动入口点（`@main` 不适用于手动 swiftc 编译）
- 实现 `StatusBarController`（22×22 彩色像素猫图标 + 基础菜单，三状态：normal/alert/paused）
- 实现 `TerminalContentMonitor`（`lsappinfo` 1s 轮询 Dock badge）
- ~~辅助功能权限引导 + 授权~~ 不再需要
- **验证：** 切到浏览器，Terminal 跑 `sleep 2 && printf "\a"` → badge 出现 → 猫弹窗

### Phase 2：透明悬浮窗 + 静态显示
- 实现 `OverlayWindowController`（`screen.visibleFrame` 避菜单栏，`hitTest` + `mouseDown` 点击猫/气泡关闭）
- 实现 `OverlayContentView`（猫咪 + 气泡布局）
- 实现 `SpeechBubbleView`（漫画气泡框）
- 内容变化 → 显示悬浮窗，点击猫/气泡 或 Esc 关闭
- **验证：** 悬浮窗覆盖全屏应用 + 菜单栏仍可点击 + 点击关闭有效

### Phase 3：动画系统
- 实现 `DropBounceAnimator`（阻尼振荡）
- 实现 `JumpBackAnimator`（抛物线弧）
- 实现 `SpriteFramePlayer`
- 绘制占位像素猫素材
- 实现 `PetSpriteView`
- **验证：** 猫从菜单栏掉落弹跳，关闭时跳回，动画流畅

### Phase 4：消息系统 + 状态机
- 实现 `NotificationStateMachine`
- 实现 `MessageProvider` + JSON 文件
- 合并通知 + 长时间未响应分类切换（2 分钟）
- **验证：** 不同场景显示正确类别话语，连续 badge 合并计数

### Phase 5：设置窗口
- 实现 `PreferencesManager`
- 实现 `SettingsView`（SwiftUI）+ `SettingsWindowController`
- 对接全部设置项（冷却、免打扰、语言等）
- 开机自启（SMAppService）
- **验证：** 设置可保存、重启后生效、冷却和免打扰按预期工作

### Phase 6：历史 + 声音 + 屏幕定位
- 实现 `NotificationHistoryManager`
- 实现 `SoundManager`
- 实现 `TerminalScreenLocator`
- 菜单中添加通知历史
- **验证：** 通知有声音，历史可查看，多显示器在终端屏幕弹出

### Phase 7：素材与打磨
- 替换占位素材为正式像素猫
- 调整动画参数和气泡样式
- 测试 macOS 13/14/15 兼容性

### Phase 8：构建与发布
- 配置代码签名
- 创建 DMG / ZIP
- 编写 README
- 创建 GitHub Release
