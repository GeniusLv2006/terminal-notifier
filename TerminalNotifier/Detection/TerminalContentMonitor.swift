import AppKit

func dbg(_ msg: String) {
    if let fh = FileHandle(forWritingAtPath: "/tmp/terminal-notifier-debug.log"),
       let data = "[CM] \(msg)\n".data(using: .utf8) {
        fh.seekToEndOfFile()
        fh.write(data)
    }
}

protocol TerminalContentMonitorDelegate: AnyObject {
    func terminalContentDidChange(_ monitor: TerminalContentMonitor)
}

class TerminalContentMonitor {
    weak var delegate: TerminalContentMonitorDelegate?
    private var timer: Timer?
    private var lastBadgeLabel: String?
    private var tickCount = 0

    func startMonitoring() {
        try? FileManager.default.removeItem(atPath: "/tmp/terminal-notifier-debug.log")
        FileManager.default.createFile(atPath: "/tmp/terminal-notifier-debug.log", contents: nil)
        dbg("startMonitoring (badge-based, no AX needed)")

        // Capture initial badge state without triggering
        lastBadgeLabel = readBadge()
        dbg("initial badge=\(lastBadgeLabel ?? "nil")")

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkBadge()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkBadge() {
        tickCount += 1
        let frontmost = isTerminalFrontmost()
        let badge = readBadge()

        if tickCount % 5 == 1 {
            dbg("tick #\(tickCount) frontmost=\(frontmost) badge=\(badge ?? "nil") lastBadge=\(lastBadgeLabel ?? "nil")")
        }

        if frontmost {
            // User is looking at Terminal — update baseline, don't trigger
            lastBadgeLabel = badge
            return
        }

        // Badge appeared (was nil, now has value) or changed (count increased)
        if let badge = badge, !badge.isEmpty, badge != "0", badge != lastBadgeLabel {
            dbg("BADGE APPEARED: \(lastBadgeLabel ?? "nil") → \(badge)")
            delegate?.terminalContentDidChange(self)
        }
        lastBadgeLabel = badge
    }

    private func isTerminalFrontmost() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return false }
        return frontApp.bundleIdentifier == "com.apple.Terminal"
    }

    private func readBadge() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/lsappinfo")
        process.arguments = ["info", "-only", "StatusLabel", "com.apple.Terminal"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.launch()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }

        // Parse ' "label"="N" ' from the output
        guard let range = output.range(of: #""label"\s*=\s*"([^"]*)""#, options: .regularExpression) else {
            // No badge: "StatusLabel"=(null) or missing
            return nil
        }
        // Extract just the numeric value
        let match = String(output[range])
        guard let valRange = match.range(of: #""[^"]*"$"#, options: .regularExpression) else { return nil }
        return String(match[valRange]).replacingOccurrences(of: "\"", with: "")
    }

    deinit {
        stopMonitoring()
    }
}
