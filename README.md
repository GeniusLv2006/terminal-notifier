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
- Xcode 或 Xcode Command Line Tools（`xcode-select --install`）

```bash
git clone https://github.com/Jack11111eee/terminal-notifier.git
cd terminal-notifier
./build.sh
open build/TerminalNotifier.app
```

## 功能

- **零权限**：无需辅助功能权限，无需屏幕录制权限
- **Claude Code 状态检测**（可选）：通过 Claude Code hook 直接区分「需要确认」和「对话完成」，不依赖终端响铃
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

开启时 App 会把 hook **安全合并**进 `~/.claude/settings.json`（保留你已有的全部 hook，并在写入前生成 `settings.json.tn-backup-<时间戳>` 备份），关闭即移除。与 badge 一致，**仅 Terminal 在后台时才弹**。

**限制：** 按 Esc「中断」时 Claude Code 不触发任何 hook，因此无法检测中断；本功能不处理输入空闲（idle）。自动合并会规整 settings.json 的格式与键序（已备份）。

## 设置

点击菜单栏猫咪 → **设置**，可以调整：

| 设置项 | 说明 | 默认值 |
|--------|------|--------|
| 启用提醒 | 开关全部提醒 | 开 |
| 检测 Claude Code 状态 | 通过 hook 区分「需要确认 / 对话完成」 | 关 |
| 开机自启 | 登录时自动启动 | 关 |
| 语言 | 中文 / 英文 / 跟随系统 | 跟随系统 |
| 声音 | 提醒时播放音效 | 开 |
| 冷却时间 | 两次提醒最短间隔 | 10 秒 |
| 免打扰 | 在指定时段暂停提醒 | 关 |
| 跳转终端 | 关闭提醒后切换到 Terminal | 关 |

## 更新日志

### v1.2.0
- **正式像素猫素材**：用手绘 PNG 像素猫替换此前代码绘制的占位猫，画面更精致；菜单栏猫的「常态 / 提醒 / 暂停」三态各有专属造型（橙 / 红 / 灰）。
- 像素渲染统一关闭抗锯齿并按整数像素对齐，放大保持硬边不糊。

### v1.1.0
- 新增 **Claude Code 状态检测**（可选）：通过 Claude Code hook 区分「需要确认」和「对话完成」，不依赖终端响铃；开启时自动安全合并 hook 进 `~/.claude/settings.json`（带备份），关闭即移除。

### v1.0.0
- 首个稳定版：菜单栏像素猫 + Terminal Dock badge 检测 + 掉落动画 + 设置/历史/声音。

## 技术栈

Swift + AppKit（主应用）+ SwiftUI（设置窗口），不依赖任何第三方框架。

## 许可

MIT License

## 致谢

灵感来自各种编程 IDE 里的宠物陪伴插件，以及总是被码头红点忽略掉的开发者们。
