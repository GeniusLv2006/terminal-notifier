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
- **全屏兼容**：即使你在全屏看视频或写代码，猫也能弹出来
- **免打扰**：设置时段（如 22:00–08:00），猫会自觉安静
- **冷却时间**：可调（5–120 秒），防止猫刷屏
- **通知历史**：查看过往提醒记录
- **中英文**：根据系统语言自动选择，也可手动设置
- **像素风**：纯正的像素艺术风格猫咪

## 设置

点击菜单栏猫咪 → **设置**，可以调整：

| 设置项 | 说明 | 默认值 |
|--------|------|--------|
| 启用提醒 | 开关全部提醒 | 开 |
| 开机自启 | 登录时自动启动 | 关 |
| 语言 | 中文 / 英文 / 跟随系统 | 跟随系统 |
| 声音 | 提醒时播放音效 | 开 |
| 冷却时间 | 两次提醒最短间隔 | 10 秒 |
| 免打扰 | 在指定时段暂停提醒 | 关 |
| 跳转终端 | 关闭提醒后切换到 Terminal | 关 |

## 技术栈

Swift + AppKit（主应用）+ SwiftUI（设置窗口），不依赖任何第三方框架。

## 许可

MIT License

## 致谢

灵感来自各种编程 IDE 里的宠物陪伴插件，以及总是被码头红点忽略掉的开发者们。
