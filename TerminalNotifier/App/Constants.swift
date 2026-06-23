import Foundation

enum Constants {
    static let appName = "Terminal Notifier"
    static let terminalAppName = "Terminal"
    static let badgePollInterval: TimeInterval = 1.0
    static let defaultPetSize: CGFloat = 240
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

    // MARK: - Codex 集成

    /// Codex hook 与 App 之间的事件目录（相对 $HOME）。
    static let codexEventsRelativePath = "Library/Application Support/TerminalNotifier/codex-events"

    /// Codex hook 执行诊断日志（相对 $HOME）。
    static let codexHookLogRelativePath = "Library/Application Support/TerminalNotifier/codex-hook.log"

    /// 写入 ~/.codex/hooks.json 的 hook 命令尾部标记，用于幂等识别与卸载。
    static let codexHookMarker = "# terminal-notifier-codex-hook"

    static var codexEventsDir: URL {
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(codexEventsRelativePath)
    }
}

enum NotificationSource: String {
    case terminal
    case claudeCode
    case codexApp

    var bundleIdentifier: String? {
        switch self {
        case .terminal, .claudeCode:
            return "com.apple.Terminal"
        case .codexApp:
            return "com.openai.codex"
        }
    }

    var windowOwnerName: String {
        switch self {
        case .terminal, .claudeCode:
            return Constants.terminalAppName
        case .codexApp:
            return "Codex"
        }
    }

    var historyBadgeLabel: String {
        switch self {
        case .terminal:
            return "terminal"
        case .claudeCode:
            return "claude-code"
        case .codexApp:
            return "codex-app"
        }
    }
}

enum MenuBarIconState {
    case normal
    case notifying
    case paused
}
