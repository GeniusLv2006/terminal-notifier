import AppKit

/// 监听 Codex hook 投放的事件标记文件。
protocol CodexAppMonitorDelegate: AnyObject {
    func codexAppMonitor(_ monitor: CodexAppMonitor, didEmit category: MessageProvider.Category)
}

class CodexAppMonitor {
    weak var delegate: CodexAppMonitorDelegate?
    private var timer: Timer?

    func startMonitoring() {
        ensureEventsDirExists()
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
            at: Constants.codexEventsDir, withIntermediateDirectories: true)
    }

    private func drainExistingMarkers() {
        for url in markerFiles() {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func poll() {
        let frontmost = isCodexFrontmost()
        for url in markerFiles() {
            let category = Self.category(forMarker: url.lastPathComponent)
            try? FileManager.default.removeItem(at: url)
            guard !frontmost, let category else { continue }
            delegate?.codexAppMonitor(self, didEmit: category)
        }
    }

    private func markerFiles() -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: Constants.codexEventsDir,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles)) ?? []
    }

    private static func category(forMarker filename: String) -> MessageProvider.Category? {
        let type = filename.components(separatedBy: ".").first ?? filename
        switch type {
        case Constants.claudeEventNeedsConfirm: return .codexNeedsConfirm
        case Constants.claudeEventDone: return .codexDone
        default: return nil
        }
    }

    private func isCodexFrontmost() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return false }
        return frontApp.bundleIdentifier == NotificationSource.codexApp.bundleIdentifier
    }

    deinit {
        stopMonitoring()
    }
}
