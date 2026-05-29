import AppKit

/// 监听 Claude Code hook 投放的事件标记文件。
///
/// hook（注册在 ~/.claude/settings.json）在「需要确认 / 对话完成」时，
/// 用 mktemp 在 `Constants.claudeEventsDir` 投放一个标记文件（文件名 `.` 之前
/// 为事件类型）。本监控每秒轮询该目录，消费（删除）标记文件并回调 delegate。
///
/// 与 TerminalContentMonitor 一致，仅在 Terminal 不在最前台时才提醒
/// （前台时用户正在看，无需打扰）。
protocol ClaudeCodeMonitorDelegate: AnyObject {
    func claudeCodeMonitor(_ monitor: ClaudeCodeMonitor, didEmit category: MessageProvider.Category)
}

class ClaudeCodeMonitor {
    weak var delegate: ClaudeCodeMonitorDelegate?
    private var timer: Timer?

    func startMonitoring() {
        ensureEventsDirExists()
        // 先清掉启动前堆积的旧标记，避免一上线就连弹。
        drainExistingMarkers()
        timer = Timer.scheduledTimer(withTimeInterval: Constants.badgePollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func ensureEventsDirExists() {
        try? FileManager.default.createDirectory(
            at: Constants.claudeEventsDir, withIntermediateDirectories: true)
    }

    /// 删除现存标记但不回调（用于启动时清场）。
    private func drainExistingMarkers() {
        for url in markerFiles() {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func poll() {
        let frontmost = isTerminalFrontmost()
        for url in markerFiles() {
            let category = Self.category(forMarker: url.lastPathComponent)
            try? FileManager.default.removeItem(at: url)
            // 前台抑制：Terminal 正在最前面时消费掉标记但不提醒。
            guard !frontmost, let category else { continue }
            delegate?.claudeCodeMonitor(self, didEmit: category)
        }
    }

    private func markerFiles() -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: Constants.claudeEventsDir,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles)) ?? []
    }

    /// 文件名 `<type>.XXXXXX` → 事件类型 → 话语分类。
    private static func category(forMarker filename: String) -> MessageProvider.Category? {
        let type = filename.components(separatedBy: ".").first ?? filename
        switch type {
        case Constants.claudeEventNeedsConfirm: return .needsConfirm
        case Constants.claudeEventDone: return .done
        default: return nil
        }
    }

    private func isTerminalFrontmost() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return false }
        return frontApp.bundleIdentifier == "com.apple.Terminal"
    }

    deinit {
        stopMonitoring()
    }
}
