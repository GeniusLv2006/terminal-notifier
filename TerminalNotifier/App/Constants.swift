import Foundation

enum Constants {
    static let appName = "Terminal Notifier"
    static let terminalAppName = "Terminal"
    static let badgePollInterval: TimeInterval = 1.0
    static let defaultPetSize: CGFloat = 320
    static let menuBarIconSize: CGFloat = 22
    static let defaultCooldown: Int = 10
    static let longWaitThreshold: TimeInterval = 120

    // MARK: - Claude Code 集成

    /// Claude Code hook 与 App 之间的事件目录（相对 $HOME）。
    /// hook 用 mktemp 在此投放标记文件，ClaudeCodeMonitor 轮询消费。
    static let claudeEventsRelativePath = "Library/Application Support/TerminalNotifier/claude-events"

    /// 标记文件类型（文件名 `.` 之前的部分）。
    static let claudeEventNeedsConfirm = "needs_confirm"
    static let claudeEventDone = "done"

    /// 写入 ~/.claude/settings.json 的 hook 命令尾部标记，用于幂等识别与卸载。
    static let claudeHookMarker = "# terminal-notifier-hook"

    static var claudeEventsDir: URL {
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(claudeEventsRelativePath)
    }
}

enum MenuBarIconState {
    case normal
    case notifying
    case paused
}
