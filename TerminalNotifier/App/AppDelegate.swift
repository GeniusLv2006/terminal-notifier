import AppKit
import ServiceManagement

func tnLog(_ msg: String) {
#if DEBUG
    if let fh = FileHandle(forWritingAtPath: "/tmp/terminal-notifier-debug.log"),
       let data = "[APP] \(msg)\n".data(using: .utf8) {
        fh.seekToEndOfFile()
        fh.write(data)
    }
#endif
}

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBarController: StatusBarController!
    private var contentMonitor: TerminalContentMonitor!
    private var claudeMonitor: ClaudeCodeMonitor!
    private var overlayController: OverlayWindowController!
    private var stateMachine: NotificationStateMachine!
    private var settingsController: SettingsWindowController!
    private var historyManager = NotificationHistoryManager()
    private var soundManager = SoundManager()
    private let preferences = PreferencesManager.shared
    private var lastLaunchAtLoginValue: Bool = false
    private var lastClaudeCodeEnabledValue: Bool = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        overlayController = OverlayWindowController()
        statusBarController = StatusBarController()
        contentMonitor = TerminalContentMonitor()
        claudeMonitor = ClaudeCodeMonitor()
        settingsController = SettingsWindowController()
        stateMachine = NotificationStateMachine()

        contentMonitor.delegate = self
        claudeMonitor.delegate = self
        stateMachine.delegate = self

        overlayController.onDismissRequested = { [weak self] in
            self?.stateMachine.handleEvent(.userDismissed)
        }
        overlayController.onDropAnimationComplete = { [weak self] in
            self?.stateMachine.handleEvent(.dropAnimationCompleted)
        }
        overlayController.onJumpBackComplete = { [weak self] in
            self?.stateMachine.handleEvent(.jumpBackCompleted)
        }

        statusBarController.onSettingsClicked = { [weak self] in
            guard let self else { return }
            self.settingsController.showSettings(preferences: self.preferences)
        }
        statusBarController.onPauseToggled = { [weak self] paused in
            if paused {
                self?.contentMonitor.stopMonitoring()
                self?.claudeMonitor.stopMonitoring()
            } else {
                self?.contentMonitor.startMonitoring()
                if self?.preferences.claudeCodeEnabled == true { self?.claudeMonitor.startMonitoring() }
            }
        }
        statusBarController.onHistoryClicked = { [weak self] in self?.showHistory() }
        statusBarController.onQuitClicked = { NSApplication.shared.terminate(nil) }

        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let current = self.preferences.launchAtLogin
            if current != self.lastLaunchAtLoginValue {
                self.lastLaunchAtLoginValue = current
                self.setLaunchAtLogin(current)
            }
            let claudeCurrent = self.preferences.claudeCodeEnabled
            if claudeCurrent != self.lastClaudeCodeEnabledValue {
                self.lastClaudeCodeEnabledValue = claudeCurrent
                self.setClaudeCodeEnabled(claudeCurrent)
            }
        }
        lastLaunchAtLoginValue = preferences.launchAtLogin
        lastClaudeCodeEnabledValue = preferences.claudeCodeEnabled

        contentMonitor.startMonitoring()
        // 持久化开启时，自愈式确保 hook 已安装并启动监控。
        if preferences.claudeCodeEnabled {
            ClaudeHookManager.install()
            claudeMonitor.startMonitoring()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        contentMonitor.stopMonitoring()
        claudeMonitor.stopMonitoring()
        overlayController.close()
    }

    /// 切换 Claude Code 状态检测：安装/卸载 hook + 启停监控。
    private func setClaudeCodeEnabled(_ enabled: Bool) {
        if enabled {
            ClaudeHookManager.install()
            claudeMonitor.startMonitoring()
        } else {
            ClaudeHookManager.uninstall()
            claudeMonitor.stopMonitoring()
        }
    }

    private func showOverlay(message: String) {
        tnLog("showOverlay: enabled=\(preferences.enabled) dnd=\(preferences.isInDNDPeriod)")
        guard preferences.enabled, !preferences.isInDNDPeriod else {
            tnLog("showOverlay BLOCKED: enabled=\(preferences.enabled) dnd=\(preferences.isInDNDPeriod)")
            return
        }
        let screen = TerminalScreenLocator.locateScreen()
        tnLog("showOverlay: calling overlayController.show screen=\(screen)")
        overlayController.show(on: screen, message: message)
        soundManager.playNotificationSound()
        tnLog("showOverlay: done")
    }

    private func showHistory() {
        let records = historyManager.getRecords()
        let alert = NSAlert()
        alert.messageText = "Notification History"
        if records.isEmpty {
            alert.informativeText = "No notifications yet."
        } else {
            alert.informativeText = records.prefix(20).map { r in
                let df = DateFormatter(); df.dateFormat = "HH:mm:ss"
                return "[\(df.string(from: r.timestamp))] \(r.message)"
            }.joined(separator: "\n")
        }
        alert.addButton(withTitle: "OK")
        if !records.isEmpty { alert.addButton(withTitle: "Clear History") }
        if alert.runModal() == .alertSecondButtonReturn { historyManager.clearHistory() }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do { if enabled { try service.register() } else { try service.unregister() } }
        catch { print("[TerminalNotifier] Launch at login error: \(error)") }
    }
}

extension AppDelegate: TerminalContentMonitorDelegate {
    func terminalContentDidChange(_ monitor: TerminalContentMonitor) {
        tnLog("terminalContentDidChange — forwarding to stateMachine")
        guard preferences.enabled, !preferences.isInDNDPeriod else {
            tnLog("terminalContentDidChange BLOCKED by prefs")
            return
        }
        stateMachine.handleEvent(.badgeDetected)
    }
}

extension AppDelegate: ClaudeCodeMonitorDelegate {
    func claudeCodeMonitor(_ monitor: ClaudeCodeMonitor, didEmit category: MessageProvider.Category) {
        tnLog("claudeCodeMonitor didEmit \(category.rawValue)")
        guard preferences.enabled, !preferences.isInDNDPeriod else {
            tnLog("claudeCodeMonitor BLOCKED by prefs")
            return
        }
        stateMachine.handleEvent(.claudeTrigger(category))
    }
}

extension AppDelegate: NotificationStateMachineDelegate {
    func stateMachine(_ sm: NotificationStateMachine, didTransitionTo state: NotificationState) {
        tnLog("stateMachine → \(state)")
        switch state {
        case .idle: statusBarController.updateIcon(state: .normal)
        case .detected: statusBarController.updateIcon(state: .notifying)
        case .showing: break
        case .animatingOut: break
        }
    }
    func stateMachine(_ sm: NotificationStateMachine, shouldShowOverlayWithMessage message: String) {
        tnLog("stateMachine: shouldShowOverlay msg=\(message)")
        historyManager.addRecord(NotificationRecord(
            id: UUID(), timestamp: Date(), badgeLabel: "content-change", message: message, category: "new_notification"))
        showOverlay(message: message)
    }
    func stateMachine(_ sm: NotificationStateMachine, shouldUpdateMessage message: String) {
        tnLog("stateMachine: shouldUpdate msg=\(message)")
        overlayController.updateMessage(message)
    }
    func stateMachineShouldDismissOverlay(_ sm: NotificationStateMachine) {
        tnLog("stateMachine: shouldDismiss")
        if preferences.switchToTerminal {
            NSWorkspace.shared.runningApplications
                .first { $0.bundleIdentifier == "com.apple.Terminal" }?
                .activate(options: .activateIgnoringOtherApps)
        }
        overlayController.beginDismiss()
    }
}
