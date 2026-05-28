import AppKit
import ApplicationServices

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
    private var lastContentHash: Int?
    private var tickCount = 0

    func startMonitoring() {
        try? FileManager.default.removeItem(atPath: "/tmp/terminal-notifier-debug.log")
        FileManager.default.createFile(atPath: "/tmp/terminal-notifier-debug.log", contents: nil)
        dbg("startMonitoring called")

        if AXIsProcessTrusted() {
            dbg("AX trusted, starting polling")
            startPolling()
            return
        }

        dbg("AX not trusted, prompting")
        let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)

        // Keep retrying — user might take time to find and toggle the permission
        scheduleRetry(attempt: 1)
    }

    private func scheduleRetry(attempt: Int) {
        let delay: TimeInterval
        switch attempt {
        case 1:  delay = 2
        case 2:  delay = 3
        case 3:  delay = 5
        default: delay = 5  // keep checking every 5s
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            if AXIsProcessTrusted() {
                dbg("AX granted after \(attempt) retries, starting")
                self.startPolling()
            } else {
                dbg("AX retry #\(attempt) — still not trusted")
                // Re-prompt in case the dialog was dismissed
                if attempt % 3 == 0 {
                    let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
                    AXIsProcessTrustedWithOptions(opts)
                }
                self.scheduleRetry(attempt: attempt + 1)
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func startPolling() {
        stopMonitoring()
        checkContent()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkContent()
        }
    }

    private func checkContent() {
        tickCount += 1
        let frontmost = isTerminalFrontmost()
        let currentHash = terminalContentHash()

        // Log every 5 ticks
        if tickCount % 5 == 1 {
            dbg("tick #\(tickCount) frontmost=\(frontmost) hash=\(currentHash.map(String.init) ?? "nil") lastHash=\(lastContentHash.map(String.init) ?? "nil")")
        }

        if frontmost {
            lastContentHash = currentHash
            return
        }

        guard let current = currentHash else {
            if tickCount % 5 == 1 { dbg("no hash available (Terminal windows not found?)") }
            return
        }

        if let last = lastContentHash, current != last {
            dbg("CONTENT CHANGED! \(last) → \(current)")
            delegate?.terminalContentDidChange(self)
        }
        lastContentHash = current
    }

    private func isTerminalFrontmost() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return false }
        return frontApp.bundleIdentifier == "com.apple.Terminal"
    }

    private func terminalContentHash() -> Int? {
        guard let termApp = NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.apple.Terminal").first else {
            return nil
        }

        let termEl = AXUIElementCreateApplication(termApp.processIdentifier)

        // Prefer the focused window, fall back to first window
        var win: AXUIElement?
        var focused: CFTypeRef?
        if AXUIElementCopyAttributeValue(termEl, "AXFocusedWindow" as CFString, &focused) == .success {
            win = (focused as! AXUIElement?)
        }
        if win == nil {
            var windows: CFTypeRef?
            AXUIElementCopyAttributeValue(termEl, "AXWindows" as CFString, &windows)
            win = (windows as? [AXUIElement])?.first
        }
        guard let targetWin = win else { return nil }

        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(targetWin, "AXChildren" as CFString, &children) == .success,
              let childList = children as? [AXUIElement],
              let splitGroup = childList.first(where: { el in
                  var role: CFTypeRef?
                  AXUIElementCopyAttributeValue(el, "AXRole" as CFString, &role)
                  return (role as? String) == "AXSplitGroup"
              }),
              let scrollArea = firstChild(of: splitGroup, role: "AXScrollArea"),
              let textArea = firstChild(of: scrollArea, role: "AXTextArea") else {
            return nil
        }

        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(textArea, "AXValue" as CFString, &value) == .success,
              let text = value as? String else { return nil }

        return text.hashValue
    }

    private func firstChild(of element: AXUIElement, role: String) -> AXUIElement? {
        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, "AXChildren" as CFString, &children) == .success,
              let childList = children as? [AXUIElement] else { return nil }
        return childList.first { el in
            var r: CFTypeRef?
            AXUIElementCopyAttributeValue(el, "AXRole" as CFString, &r)
            return (r as? String) == role
        }
    }

    deinit {
        stopMonitoring()
    }
}
