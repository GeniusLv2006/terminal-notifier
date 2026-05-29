# Terminal Pet Notifier — 最终确认规格书

> 基于 DETAIL-CONFIRM.md 用户填写结果整理，2026-05-27

---

## 1. 产品概要

**一句话描述**：一个 macOS 菜单栏像素猫应用，当 Terminal.app 在后台出现新输出时（如 Claude Code 等待命令确认），像素猫从菜单栏掉落到屏幕上，用漫画气泡提醒你去查看终端。

**核心场景**：用户在使用 Claude Code / Codex CLI 时，终端等待命令确认或任务中断，但用户切到了其他窗口没注意到。

> 2026-05-28 更新 v2：最终切换为 `lsappinfo` 读取 Terminal Dock badge。之前尝试的 AX 文本内容监控因 Terminal AX 渲染噪音导致频繁误触发，已废弃。Badge 检测无需辅助功能权限，准确率 100%。

---

## 2. 已确认决策

### 2.1 触发源

| 项目 | 决策 |
|------|------|
| 支持终端 | 仅 Terminal.app（第一版） |
| 触发事件 | Terminal 在后台时 Dock 出现红点 badge |
| 前台抑制 | Terminal 在最前面时不触发（用户正在看） |
| 检测方式 | 1 秒轮询 `lsappinfo info -only StatusLabel com.apple.Terminal` 读取 Dock badge 值 |

> **2026-05-29 新增：Claude Code 状态检测（第二触发源）**
> badge 只能告诉你「有动静」，区分不了类型，且依赖终端响铃。新增一条独立信号源——
> 通过 Claude Code 官方 **hooks** 直接读对话状态：
> - `Notification`（`matcher: permission_prompt`）→ **需要确认**
> - `Stop` → **对话完成**
>
> hook 用 `mktemp` 在 `~/Library/Application Support/TerminalNotifier/claude-events/` 投放标记文件，
> App 每秒轮询消费。设置里「检测 Claude Code 状态」开关控制（默认关，opt-in）；开启时 App
> 自动把 hook **安全合并**进 `~/.claude/settings.json`（保留既有 hook + 时间戳备份），关闭即移除。
>
> **取舍**：与 badge 一致，**仅 Terminal 后台时才弹**（前台你在看，不打扰）。**不处理 idle**。
> **中断（Esc）无法检测**——Claude Code 官方在用户中断时不触发任何 hook，`Stop` 仅在 Claude
> 自己说完时触发，无中断专用 hook。

### 2.2 菜单栏宠物

| 项目 | 决策 |
|------|------|
| 角色 | 像素猫 |
| 风格 | 像素风（Pixel Art） |
| 多宠物可选 | 后续迭代 |
| 待机状态 | 静止头像，无动画 |
| 点击行为 | 弹出下拉菜单 |
| 菜单项 | 设置、暂停提醒、通知历史、退出 |

### 2.3 全屏提醒

| 项目 | 决策 |
|------|------|
| 出场方式 | 从菜单栏位置掉落（重力 + 弹跳） |
| 宠物尺寸 | 默认 300px，后续可在设置中调 |
| 话语内容 | 按事件分类，每类 5 句预设，随机选 |
| 话语语言 | 默认根据系统语言设置（暂仅支持中/英），但设置中也可以设置语言 |
| 气泡样式 | 漫画气泡框 |
| 背景 | 完全透明，悬浮在当前内容上方 |
| 自动消失 | 否，需手动关闭 |
| 消失方式 | 点击宠物/气泡 或 按 Esc |
| 消失后跳转终端 | 可选（设置项） |
| 退场动画 | 跳回菜单栏 |
| 连续触发 | 合并显示（"你有 N 条终端通知"） |

> **合并计数的实际触发条件（重要）**：Dock 角标数 = Terminal 后台「有未读响铃的标签/窗口数」，**不是响铃总次数**。同一标签页内连响多次，角标恒为 `1`，`lsappinfo` 读到的值不变，不会累加。因此"你有 N 条通知"只在用户同时挂着 **多个后台窗口/标签且各自响铃** 时出现，单会话场景基本恒为 1。这是 badge 检测方案的固有粒度限制——badge 只能告诉我们"有几个会话有通知"，给不了"某会话来了几条"。要做到后者需读取终端窗口文本（需屏幕录制权限，见 §3.3 已放弃方案）。

### 2.4 声音

| 项目 | 决策 |
|------|------|
| 声音 | 用户可选，默认开 |

### 2.5 设置

| 项目 | 决策 |
|------|------|
| 界面 | 独立设置窗口 |
| 启用/禁用 | ✓ |
| 免打扰时段 | ✓ |
| 冷却时间 | ✓（间隔值待定，建议默认 10 秒） |
| 宠物选择 | ✓（第一版只有一只猫，预留接口） |
| 声音开关 | ✓ |
| 开机自启 | ✓ |
| 自定义提醒语 | 第一版不做 |

### 2.6 多屏幕 / 全屏

| 项目 | 决策 |
|------|------|
| 多显示器 | 在终端所在屏幕弹出 |
| 全屏应用中 | 照常弹出 |

### 2.7 分发

| 项目 | 决策 |
|------|------|
| 方式 | GitHub Release |
| macOS 最低版本 | macOS 13 Ventura |

---

## 3. 我的技术推荐（需你确认）

### 3.1 开发框架：Swift + AppKit（主） + SwiftUI（设置窗口）

**我的回答**：OK，开发框架就Swift + AppKit（主） + SwiftUI（设置窗口）

**理由**：
- 菜单栏应用（NSStatusItem）、透明悬浮窗口（NSWindow）、Dock badge 检测（lsappinfo）都是 AppKit 领域，SwiftUI 在这些场景下限制多且坑多
- 设置窗口用 SwiftUI 写更快更现代，可以通过 NSHostingController 嵌入
- macOS 13+ 完全支持
- 原生轻量，无 Electron 那种 200MB+ 的体积问题

### 3.2 动画实现：Sprite Sheet + Core Animation

**我的回答**：OK，动画实现就Sprite Sheet + Core Animation实现。

**理由**：
- 像素风天然适合序列帧（Sprite Sheet），每个动作状态一组帧
- 掉落/弹跳/跳回的物理运动用 Core Animation（CAKeyframeAnimation）控制位移曲线
- 比 SpriteKit 轻量，不需要引入游戏引擎
- 比 Lottie 更适合像素风，Lottie 偏向矢量/设计师风格

**需要准备的 Sprite Sheet**：

| 动作 | 帧数（建议） | 说明 |
|------|-------------|------|
| idle | 1 帧 | 菜单栏静止头像（18×18px） |
| drop | 4-6 帧 | 掉落中的姿势 |
| land | 3-4 帧 | 落地弹跳 |
| talk | 2-4 帧 | 说话时的微动（嘴巴开合等） |
| jump_back | 4-6 帧 | 跳回菜单栏 |

第一版可以极简：idle 1 帧 + 其余用 Core Animation 位移模拟，后续再加帧动画丰富度。

### 3.3 终端变化检测方案（已实现）

实现中经历多次迭代：

| 尝试 | 方案 | 结果 |
|------|------|------|
| lsappinfo "Terminal" | `lsappinfo info -only StatusLabel "Terminal"` | 失败——应用名不匹配 |
| AX API 读 AXStatusLabel | 读 Dock 中 Terminal 元素的 badge 属性 | 返回 error -25212（kAXErrorAttributeUnsupported）|
| AX API 监控文本内容 | 读 Terminal AXTextArea 文本 hash/prefix 比较 | 有效但误触发严重——Terminal AX 渲染值不断变化 |
| **lsappinfo com.apple.Terminal** | `lsappinfo info -only StatusLabel com.apple.Terminal` | **最终方案**。直接用 Bundle ID，准确读取 badge 值 |

**最终方案**：`lsappinfo` 配合 Bundle ID 读取 Dock badge，1 秒轮询。无需辅助功能权限。Terminal 不在最前面 + badge 出现（label != nil/0）→ 触发提醒。

---

## 4. 提醒话语分类体系（需你确认/补充）

根据你提到的 Claude Code / Codex CLI 场景，我建议以下分类：

### 分类及示例（中文版，每类 5 句）

**类别 1：命令等待确认**
> 检测到 badge 出现，通用场景

1. 喵~ 终端在叫你！快去看看吧
2. 有消息啦！终端那边需要你
3. 嘿！终端亮红灯了，去瞧瞧？
4. 终端有动静了，别忘了哦~
5. 喵呜！你的终端在等你回复呢

**类别 2：长时间未响应**
> badge 持续存在超过一定时间（如 2 分钟）

1. 喂喂喂，终端等你好久了！
2. 终端都急了...快去看看吧！
3. 你是不是忘了终端还开着？
4. 已经过了好一会儿了，终端还在等你...
5. 再不去看，终端要生气了喵！

> **问题**：你是否需要更多分类？比如区分"任务完成"vs"任务中断"vs"等待确认"？如果要区分，仅靠 Dock badge 无法判断具体是哪种事件——badge 只告诉我们"有通知"，不告诉我们通知内容。要做细分需要额外手段（如读取终端窗口文本，需要屏幕录制权限）。

**我的回答**：暂时不需要更多分类，这个后续可以添加。

---

## 5. 需要你再确认的问题

| # | 问题 | 建议 |
|---|------|------|
| Q1 | 技术栈选 Swift + AppKit 主 + SwiftUI 设置窗口，OK？ | OK |
| Q2 | 动画用 Sprite Sheet + Core Animation，OK？ | OK |
| Q3 | Badge 检测用 lsappinfo CLI（无需辅助功能权限），OK？ | OK |
| Q4 | 冷却时间默认值 30 秒是否合适？ | 10秒 |
| Q5 | 声音默认开还是默认关？ | 默认开 |
| Q6 | 话语分类：仅靠 badge 只能分"刚出现"和"长时间未响应"两类。如果要区分具体事件类型（任务完成/中断/等待确认），需要读取终端窗口文本（额外需要屏幕录制权限）。第一版你想要哪种？ | 第一版先做两类，后续加细分 |
| Q7 | 像素猫的素材：我来生成/绘制一版占位素材先跑通，你后续替换？还是你想先选定素材？ | 你先生成/绘制一版占位素材先跑通，我后续替换或者更新 |
| Q8 | 应用名称？Terminal Pet Notifier？还是你有更好的名字？ | 就叫Terminal Notifier |

---

请对 Q1-Q8 回复确认或修改，我们就可以开始技术方案设计了。
