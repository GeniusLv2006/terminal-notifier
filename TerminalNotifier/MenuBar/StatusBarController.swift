import AppKit

class StatusBarController {
    private let statusItem: NSStatusItem
    private let menu: NSMenu
    private var isPaused: Bool = false
    private var pauseMenuItem: NSMenuItem?

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
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(settingsAction),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let pauseItem = NSMenuItem(
            title: "Pause Notifications",
            action: #selector(pauseAction),
            keyEquivalent: ""
        )
        pauseItem.target = self
        menu.addItem(pauseItem)
        pauseMenuItem = pauseItem

        let historyItem = NSMenuItem(
            title: "Notification History",
            action: #selector(historyAction),
            keyEquivalent: ""
        )
        historyItem.target = self
        menu.addItem(historyItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Terminal Notifier",
            action: #selector(quitAction),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
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
        if let pauseItem = pauseMenuItem {
            pauseItem.title = isPaused ? "Resume Notifications" : "Pause Notifications"
        }
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
}
