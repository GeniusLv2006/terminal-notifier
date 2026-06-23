import AppKit

class StatusBarController {
    private let statusItem: NSStatusItem
    private let menu: NSMenu
    private var isPaused: Bool = false

    var onSettingsClicked: (() -> Void)?
    var onPauseToggled: ((Bool) -> Void)?
    var onHistoryClicked: (() -> Void)?
    var onQuitClicked: (() -> Void)?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        menu = NSMenu()

        setupStatusItem()
        setupMenu()
        print("[TerminalNotifier] Status bar item created. Button: \(statusItem.button != nil ? "OK" : "NIL")")
    }

    private func setupStatusItem() {
        guard let button = statusItem.button else {
            print("[TerminalNotifier] ERROR: statusItem.button is nil")
            return
        }
        button.image = Self.createColoredCatIcon(size: 22)
        button.imagePosition = .imageOnly
        print("[TerminalNotifier] Icon set on status bar button")
    }

    private func setupMenu() {
        rebuildMenu()
        statusItem.menu = menu
    }

    func refreshMenu() {
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let appItem = NSMenuItem(title: "Terminal Notifier", action: nil, keyEquivalent: "")
        appItem.isEnabled = false
        menu.addItem(appItem)

        menu.addItem(sectionHeader(menuLang("Status", zh: "状态")))

        let notificationState = isPaused
            ? menuLang("Paused", zh: "已暂停")
            : (PreferencesManager.shared.enabled ? menuLang("Active", zh: "运行中") : menuLang("Disabled", zh: "已关闭"))
        let statusItem = NSMenuItem(
            title: "\(menuLang("Notifications", zh: "提醒")): \(notificationState)",
            action: nil,
            keyEquivalent: ""
        )
        statusItem.image = isPaused ? Self.createPausedIcon(size: 16) : Self.createColoredCatIcon(size: 16)
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        let claudeState = PreferencesManager.shared.claudeCodeEnabled
            ? menuLang("On", zh: "已开启")
            : menuLang("Off", zh: "未开启")
        let claudeItem = NSMenuItem(
            title: "Claude Code: \(claudeState)",
            action: nil,
            keyEquivalent: ""
        )
        claudeItem.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: nil)
        claudeItem.isEnabled = false
        menu.addItem(claudeItem)

        let codexState = PreferencesManager.shared.codexAppEnabled
            ? menuLang("On", zh: "已开启")
            : menuLang("Off", zh: "未开启")
        let codexItem = NSMenuItem(
            title: "Codex: \(codexState)",
            action: nil,
            keyEquivalent: ""
        )
        codexItem.image = NSImage(systemSymbolName: "macwindow", accessibilityDescription: nil)
        codexItem.isEnabled = false
        menu.addItem(codexItem)

        menu.addItem(.separator())
        menu.addItem(sectionHeader(menuLang("Actions", zh: "操作")))

        let settingsItem = NSMenuItem(
            title: menuLang("Settings...", zh: "设置..."),
            action: #selector(settingsAction),
            keyEquivalent: ","
        )
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        settingsItem.target = self
        menu.addItem(settingsItem)

        let pauseItem = NSMenuItem(
            title: isPaused ? menuLang("Resume Notifications", zh: "恢复提醒") : menuLang("Pause Notifications", zh: "暂停提醒"),
            action: #selector(pauseAction),
            keyEquivalent: ""
        )
        pauseItem.image = NSImage(systemSymbolName: isPaused ? "play.circle" : "pause.circle", accessibilityDescription: nil)
        pauseItem.target = self
        menu.addItem(pauseItem)

        let historyItem = NSMenuItem(
            title: menuLang("Notification History", zh: "提醒历史"),
            action: #selector(historyAction),
            keyEquivalent: ""
        )
        historyItem.image = NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: nil)
        historyItem.target = self
        menu.addItem(historyItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: menuLang("Quit Terminal Notifier", zh: "退出 Terminal Notifier"),
            action: #selector(quitAction),
            keyEquivalent: "q"
        )
        quitItem.image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: nil)
        quitItem.target = self
        menu.addItem(quitItem)
    }

    func updateIcon(state: MenuBarIconState) {
        DispatchQueue.main.async {
            guard let button = self.statusItem.button else { return }
            switch state {
            case .normal:
                button.image = Self.createColoredCatIcon(size: Constants.menuBarIconSize)
            case .notifying:
                button.image = Self.createAlertCatIcon(size: Constants.menuBarIconSize)
            case .paused:
                button.image = Self.createPausedIcon(size: Constants.menuBarIconSize)
            }
        }
    }

    func updatePauseMenuItem(isPaused: Bool) {
        self.isPaused = isPaused
        rebuildMenu()
    }

    @objc private func settingsAction() { onSettingsClicked?() }
    @objc private func pauseAction() {
        isPaused.toggle()
        updatePauseMenuItem(isPaused: isPaused)
        updateIcon(state: isPaused ? .paused : .normal)
        onPauseToggled?(isPaused)
    }
    @objc private func historyAction() { onHistoryClicked?() }
    @objc private func quitAction() { onQuitClicked?() }

    // MARK: - Colored Cat Icon (visible on any menu bar)

    static func createColoredCatIcon(size: CGFloat) -> NSImage {
        return menuBarCatImage(size: size, source: normalImage)
    }

    static func createAlertCatIcon(size: CGFloat) -> NSImage {
        return menuBarCatImage(size: size, source: notifyingImage)
    }

    static func createPausedIcon(size: CGFloat) -> NSImage {
        return menuBarCatImage(size: size, source: pausedImage)
    }

    // 菜单栏猫素材(11×11 设计,@2x PNG),三态各一张。加载一次复用。
    private static let normalImage = loadCat("MenuBarCat")
    private static let notifyingImage = loadCat("MenuBarCatNotifying")
    private static let pausedImage = loadCat("MenuBarCatPaused")

    private static func loadCat(_ name: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }

    private static func menuBarCatImage(size: CGFloat, source: NSImage?) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))

        image.lockFocus()
        if let ctx = NSGraphicsContext.current {
            ctx.imageInterpolation = .none
            ctx.cgContext.setShouldAntialias(false)
        }
        source?.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
        image.unlockFocus()
        return image
    }

    private func sectionHeader(_ title: String) -> NSMenuItem {
        if #available(macOS 14.0, *) {
            return NSMenuItem.sectionHeader(title: title)
        }

        let item = NSMenuItem(title: title.uppercased(), action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func menuLang(_ en: String, zh: String) -> String {
        PreferencesManager.shared.resolvedLocale == "zh" ? zh : en
    }
}
