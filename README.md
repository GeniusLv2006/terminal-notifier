# Terminal Notifier

> 一只住在 macOS 菜单栏的像素猫，会提醒你该看终端了。

## 这是什么？

你在用 Claude Code 或 Codex CLI 时，是不是经常切到浏览器，然后忘了终端正等着你确认命令？

Terminal Notifier 会检测 Terminal.app 的 Dock 红点（badge）。一旦检测到，菜单栏里的像素猫就会从屏幕顶部落下来，弹到你面前，用气泡告诉你："喵~ 该看终端啦！"

## 效果演示

1. 像素猫安静地住在菜单栏里 🐱
2. Terminal.app 的 Dock 图标出现红点（badge）
3. 猫掉下来，弹跳落地，弹出气泡："喵~ 终端在叫你！"
4. 你点击猫或按 Esc → 猫跳回菜单栏 → 自动切到 Terminal 窗口（可选）
5. 10 秒冷却后，猫继续待命

## 安装

### 直接下载

从 [GitHub Releases](https://github.com/Jack11111eee/terminal-notifier/releases) 下载最新的 `.zip` 文件，解压后将 `TerminalNotifier.app` 拖到 `Applications` 文件夹即可。

### 从源码编译

**要求：**
- macOS 13 Ventura 及以上
- Apple Silicon Mac
- Xcode 或 Xcode Command Line Tools（`xcode-select --install`）
- 登录钥匙串中有代码签名证书 `TerminalNotifierDev`，用于保持辅助功能权限跨重编译稳定

```bash
git clone https://github.com/Jack11111eee/terminal-notifier.git
cd terminal-notifier
./build.sh
open build/TerminalNotifier.app
```

如需构建后复制到 `/Applications`：

```bash
INSTALL=1 ./build.sh
```

## 功能

- **Badge 基础检测零权限**：默认只读 Terminal Dock badge，无需辅助功能权限或屏幕录制权限
- **Claude Code / Codex 状态检测**（可选）：通过 hook 直接区分「需要确认」和「对话完成」，不依赖终端响铃
- **Claude 前台多窗口归因**：Terminal.app 在前台时，Claude hook 事件来自非最上层 Terminal 窗口也会提醒
- **全屏兼容**：即使你在全屏看视频或写代码，猫也能弹出来
- **免打扰**：设置时段（如 22:00–08:00），猫会自觉安静
- **冷却时间**：可调（5–120 秒），防止猫刷屏
- **通知历史**：查看过往提醒记录
- **中英文**：根据系统语言自动选择，也可手动设置
- **像素风**：纯正的像素艺术风格猫咪

## Claude Code 状态检测（可选）

默认的 badge 检测只能知道「终端有动静」。打开设置里的 **检测 Claude Code 状态** 后，App 会通过 Claude Code 官方 hook 直接读对话状态，区分两种事件并弹出对应话语：

- **需要确认**：Claude 等你批准某个操作（`Notification` / `permission_prompt`）
- **对话完成**：Claude 说完一轮（`Stop`）

开启时 App 会把 hook **安全合并**进 `~/.claude/settings.json`（保留你已有的全部 hook，并在写入前生成 `settings.json.tn-backup-<时间戳>` 备份），关闭即移除。Terminal 在后台时直接提醒；Terminal 在前台且有多个可见窗口时，App 会用 hook marker 里的 TTY 归因到来源窗口，只有来源不是最上层 Terminal 窗口时才提醒。归因失败或来源就是最上层窗口时继续抑制。

**权限与限制：** Badge 基础检测仍无需权限。Claude 前台多窗口归因会请求辅助功能权限，并可能请求控制 Terminal 的自动化权限；关闭提醒后跳转来源窗口也依赖该能力。按 Esc「中断」时 Claude Code 不触发任何 hook，因此无法检测中断；本功能不处理输入空闲（idle）。自动合并会规整 settings.json 的格式与键序（已备份）。

## Codex 状态检测（可选）

打开设置里的 **检测 Codex 状态** 后，App 会通过 Codex lifecycle hooks 捕捉两类事件：

- **需要确认**：Codex 等你批准某个操作（`PermissionRequest`）
- **对话完成**：Codex 完成一轮（`Stop`）

开启时 App 会把受管理的 hooks **安全合并**进 `~/.codex/hooks.json`（保留你已有的全部 hooks，并在写入前生成 `hooks.json.tn-backup-<时间戳>` 备份），关闭即移除。与 badge 一致，**仅 Codex 不在前台时才弹**。

**必须信任 hooks：** 开启后请重启或重新打开 Codex，然后进入 Codex **设置 → 钩子**，审核并信任 `PermissionRequest` 和 `Stop` 两项。未信任前 Codex 会跳过这些 hooks，Terminal Notifier 不会收到提醒。

**已知问题：** Codex 的 `auto-review` 流程仍可能发出 `PermissionRequest` hook，因此即使 Codex 自动完成审核，也可能出现「需要确认」提醒。

**限制：** Codex hooks 是用户级配置，可能同时被本机 Codex App / CLI / IDE Extension 采用；当前不区分具体 Codex 入口，也不读取 Codex App 内部实时运行状态。若需要排查 hook 是否执行，可查看 `~/Library/Application Support/TerminalNotifier/codex-hook.log`。

## 设置

点击菜单栏猫咪 → **设置**，可以调整：

| 设置项 | 说明 | 默认值 |
|--------|------|--------|
| 启用提醒 | 开关全部提醒 | 开 |
| 检测 Claude Code 状态 | 通过 hook 区分「需要确认 / 对话完成」 | 关 |
| 检测 Codex 状态 | 通过 Codex hook 区分「需要确认 / 对话完成」 | 关 |
| 开机自启 | 登录时自动启动 | 关 |
| 语言 | 中文 / 英文 / 跟随系统 | 跟随系统 |
| 声音 | 提醒时播放音效 | 开 |
| 冷却时间 | 两次提醒最短间隔 | 10 秒 |
| 免打扰 | 在指定时段暂停提醒 | 关 |
| 跳转来源应用 | 关闭提醒后切换到 Terminal / Codex；Claude 多窗口事件优先跳到来源窗口 | 关 |

## 更新日志

### Unreleased
- Claude Code 状态检测增加 Terminal 前台多窗口归因：事件来自非最上层 Terminal 窗口时也会提醒，关闭后可跳到来源窗口。
- Claude hook marker 改为 JSON，包含事件类型、来源、TTY 和时间戳；旧版空 marker 仍兼容。

### v1.2.1
- **修复语言切换无效**：设置界面此前只读系统语言、无视用户选择，与通知话语逻辑割裂；现统一判定，选完即时切换，设置界面与话语语言保持一致。
- 设置里宠物选项改名为「橘猫」。
- 冷却时间由滑块改为下拉选择（5/10/15/30/60/120 秒）。

### v1.2.0
- **正式像素猫素材**：用手绘 PNG 像素猫替换此前代码绘制的占位猫，画面更精致；菜单栏猫的「常态 / 提醒 / 暂停」三态各有专属造型（橙 / 红 / 灰）。
- 像素渲染统一关闭抗锯齿并按整数像素对齐，放大保持硬边不糊。

### v1.1.0
- 新增 **Claude Code 状态检测**（可选）：通过 Claude Code hook 区分「需要确认」和「对话完成」，不依赖终端响铃；开启时自动安全合并 hook 进 `~/.claude/settings.json`（带备份），关闭即移除。

### v1.0.0
- 首个稳定版：菜单栏像素猫 + Terminal Dock badge 检测 + 掉落动画 + 设置/历史/声音。

## 技术栈

Swift + AppKit（主应用）+ SwiftUI（设置窗口），不依赖任何第三方框架。

## 文档

- [使用说明](docs/USER-GUIDE.md)
- [架构说明](docs/ARCHITECTURE.md)

## 许可

MIT License

## 致谢

灵感来自各种编程 IDE 里的宠物陪伴插件，以及总是被码头红点忽略掉的开发者们。
