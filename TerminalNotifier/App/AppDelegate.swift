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
    private var codexMonitor: CodexAppMonitor!
    private var overlayController: OverlayWindowController!
    private var stateMachine: NotificationStateMachine!
    private var settingsController: SettingsWindowController!
    private var historyController: HistoryWindowController!
    private var historyManager = NotificationHistoryManager()
    private var soundManager = SoundManager()
    private let preferences = PreferencesManager.shared
    private var lastLaunchAtLoginValue: Bool = false
    private var lastClaudeCodeEnabledValue: Bool = false
    private var lastCodexAppEnabledValue: Bool = false
    private var currentOverlaySource: NotificationSource = .terminal

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let previewMode = PreviewMode.current {
            startPreview(mode: previewMode)
            return
        }

        overlayController = OverlayWindowController()
        statusBarController = StatusBarController()
        contentMonitor = TerminalContentMonitor()
        claudeMonitor = ClaudeCodeMonitor()
        codexMonitor = CodexAppMonitor()
        settingsController = SettingsWindowController()
        historyController = HistoryWindowController()
        stateMachine = NotificationStateMachine()

        contentMonitor.delegate = self
        claudeMonitor.delegate = self
        codexMonitor.delegate = self
        stateMachine.delegate = self

        overlayController.onDismissRequested = { [weak self] in
            self?.stateMachine.handleEvent(.userDismissed)
        }
        overlayController.onDropAnimationComplete = { [weak self] in
            self?.stateMachine.handleEvent(.dropAnimationCompleted)
        }
        overlayController.onJumpBackComplete = { [weak self] in
            guard let self else { return }
            self.stateMachine.handleEvent(.jumpBackCompleted)
            self.overlayController.forceClose()
        }

        statusBarController.onSettingsClicked = { [weak self] in
            guard let self else { return }
            self.settingsController.showSettings(preferences: self.preferences)
        }
        statusBarController.onPauseToggled = { [weak self] paused in
            if paused {
                self?.contentMonitor.stopMonitoring()
                self?.claudeMonitor.stopMonitoring()
                self?.codexMonitor.stopMonitoring()
            } else {
                self?.contentMonitor.startMonitoring()
                if self?.preferences.claudeCodeEnabled == true { self?.claudeMonitor.startMonitoring() }
                if self?.preferences.codexAppEnabled == true { self?.codexMonitor.startMonitoring() }
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
            let codexCurrent = self.preferences.codexAppEnabled
            if codexCurrent != self.lastCodexAppEnabledValue {
                self.lastCodexAppEnabledValue = codexCurrent
                self.setCodexAppEnabled(codexCurrent)
            }
            self.statusBarController.refreshMenu()
        }
        lastLaunchAtLoginValue = preferences.launchAtLogin
        lastClaudeCodeEnabledValue = preferences.claudeCodeEnabled
        lastCodexAppEnabledValue = preferences.codexAppEnabled

        contentMonitor.startMonitoring()
        // 持久化开启时，自愈式确保 hook 已安装并启动监控。
        if preferences.claudeCodeEnabled {
            if !ClaudeHookManager.install() {
                print("[TerminalNotifier] Claude Code hook install failed")
            }
            claudeMonitor.startMonitoring()
        }
        if preferences.codexAppEnabled {
            if !CodexHookManager.install() {
                print("[TerminalNotifier] Codex hook install failed")
            }
            codexMonitor.startMonitoring()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        contentMonitor?.stopMonitoring()
        claudeMonitor?.stopMonitoring()
        codexMonitor?.stopMonitoring()
        overlayController?.close()
    }

    /// 切换 Claude Code 状态检测：安装/卸载 hook + 启停监控。
    private func setClaudeCodeEnabled(_ enabled: Bool) {
        if enabled {
            if !ClaudeHookManager.install() {
                print("[TerminalNotifier] Claude Code hook install failed")
            }
            claudeMonitor.startMonitoring()
        } else {
            if !ClaudeHookManager.uninstall() {
                print("[TerminalNotifier] Claude Code hook uninstall failed")
            }
            claudeMonitor.stopMonitoring()
        }
    }

    /// 切换 Codex 状态检测：安装/卸载 hook + 启停监控。
    private func setCodexAppEnabled(_ enabled: Bool) {
        if enabled {
            if !CodexHookManager.install() {
                print("[TerminalNotifier] Codex hook install failed")
            }
            codexMonitor.startMonitoring()
        } else {
            if !CodexHookManager.uninstall() {
                print("[TerminalNotifier] Codex hook uninstall failed")
            }
            codexMonitor.stopMonitoring()
        }
    }

    private func showOverlay(message: String, source: NotificationSource) {
        tnLog("showOverlay: enabled=\(preferences.enabled) dnd=\(preferences.isInDNDPeriod)")
        guard preferences.enabled, !preferences.isInDNDPeriod else {
            tnLog("showOverlay BLOCKED: enabled=\(preferences.enabled) dnd=\(preferences.isInDNDPeriod)")
            return
        }
        let screen = TerminalScreenLocator.locateScreen(ownerName: source.windowOwnerName)
        tnLog("showOverlay: calling overlayController.show screen=\(screen)")
        overlayController.show(on: screen, message: message)
        soundManager.playNotificationSound()
        tnLog("showOverlay: done")
    }

    private func showHistory() {
        historyController.showHistory(historyManager: historyManager)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do { if enabled { try service.register() } else { try service.unregister() } }
        catch { print("[TerminalNotifier] Launch at login error: \(error)") }
    }

    private func startPreview(mode: PreviewMode) {
        settingsController = SettingsWindowController()
        historyController = HistoryWindowController()
        overlayController = OverlayWindowController()
        historyManager = Self.previewHistoryManager()

        overlayController.onDismissRequested = { [weak self] in
            self?.overlayController.beginDismiss()
        }
        overlayController.onJumpBackComplete = { [weak self] in
            guard let self else { return }
            self.overlayController.forceClose()
        }

        NSApp.activate(ignoringOtherApps: true)

        switch mode {
        case .settings:
            settingsController.showSettings(preferences: preferences)
        case .history:
            historyController.showHistory(historyManager: historyManager)
        case .overlay:
            showPreviewOverlay()
        case .all:
            settingsController.showSettings(preferences: preferences)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.historyController.showHistory(historyManager: self.historyManager)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.showPreviewOverlay()
            }
        }
    }

    private func showPreviewOverlay() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        overlayController.show(
            on: screen,
            message: preferences.resolvedLocale == "zh"
                ? "点击猫或气泡关闭"
                : "Click the pet or bubble to dismiss"
        )
    }

    private static func previewHistoryManager() -> NotificationHistoryManager {
        let manager = NotificationHistoryManager(storageKey: "notificationHistoryPreview")
        manager.clearHistory()
        manager.addRecord(NotificationRecord(
            id: UUID(),
            timestamp: Date().addingTimeInterval(-80),
            badgeLabel: "preview",
            message: "Claude needs your confirmation.",
            category: MessageProvider.Category.needsConfirm.rawValue
        ))
        manager.addRecord(NotificationRecord(
            id: UUID(),
            timestamp: Date().addingTimeInterval(-260),
            badgeLabel: "preview",
            message: "Terminal notification detected in the active session.",
            category: MessageProvider.Category.newNotification.rawValue
        ))
        manager.addRecord(NotificationRecord(
            id: UUID(),
            timestamp: Date().addingTimeInterval(-540),
            badgeLabel: "preview",
            message: "Claude is done.",
            category: MessageProvider.Category.done.rawValue
        ))
        return manager
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
        stateMachine.handleEvent(.agentTrigger(category, .claudeCode))
    }
}

extension AppDelegate: CodexAppMonitorDelegate {
    func codexAppMonitor(_ monitor: CodexAppMonitor, didEmit category: MessageProvider.Category) {
        tnLog("codexAppMonitor didEmit \(category.rawValue)")
        guard preferences.enabled, !preferences.isInDNDPeriod else {
            tnLog("codexAppMonitor BLOCKED by prefs")
            return
        }
        stateMachine.handleEvent(.agentTrigger(category, .codexApp))
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
    func stateMachine(
        _ sm: NotificationStateMachine,
        shouldShowOverlayWithMessage message: String,
        category: MessageProvider.Category,
        source: NotificationSource
    ) {
        tnLog("stateMachine: shouldShowOverlay msg=\(message)")
        currentOverlaySource = source
        historyManager.addRecord(NotificationRecord(
            id: UUID(),
            timestamp: Date(),
            badgeLabel: source.historyBadgeLabel,
            message: message,
            category: category.rawValue))
        showOverlay(message: message, source: source)
    }
    func stateMachine(
        _ sm: NotificationStateMachine,
        shouldUpdateMessage message: String,
        category: MessageProvider.Category,
        source: NotificationSource
    ) {
        tnLog("stateMachine: shouldUpdate msg=\(message)")
        currentOverlaySource = source
        overlayController.updateMessage(message)
    }
    func stateMachineShouldDismissOverlay(_ sm: NotificationStateMachine) {
        tnLog("stateMachine: shouldDismiss")
        if preferences.switchToTerminal {
            NSWorkspace.shared.runningApplications
                .first { $0.bundleIdentifier == currentOverlaySource.bundleIdentifier }?
                .activate(options: .activateIgnoringOtherApps)
        }
        overlayController.beginDismiss()
    }
}
