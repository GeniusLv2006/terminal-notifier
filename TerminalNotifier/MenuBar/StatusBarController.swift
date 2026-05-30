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
        return drawColoredCat(size: size, isAlert: false, isPaused: false)
    }

    static func createAlertCatIcon(size: CGFloat) -> NSImage {
        return drawColoredCat(size: size, isAlert: true, isPaused: false)
    }

    static func createPausedIcon(size: CGFloat) -> NSImage {
        return drawColoredCat(size: size, isAlert: false, isPaused: true)
    }

    private static func drawColoredCat(size: CGFloat, isAlert: Bool, isPaused: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))

        image.lockFocus()
        NSGraphicsContext.current?.cgContext.setShouldAntialias(false)

        let pixel = size / 11.0
        let bodyColor: NSColor
        let earColor: NSColor

        if isPaused {
            bodyColor = NSColor.gray
            earColor = NSColor.darkGray
        } else if isAlert {
            bodyColor = NSColor.systemRed
            earColor = NSColor.red
        } else {
            bodyColor = NSColor(red: 1.0, green: 0.65, blue: 0.15, alpha: 1.0)   // orange
            earColor = NSColor(red: 0.85, green: 0.40, blue: 0.10, alpha: 1.0)    // dark orange
        }

        // 11x11 pixel grid cat face
        let rows: [String] = [
            "...........",
            "..EE...EE..",
            ".EBOE.EOBE.",
            ".EBBBEBBBE.",
            "..BBBBBBB..",
            "..BBK.BKB..",
            ".BBBWWWBBB.",
            ".BBBBBBBBB.",
            ".BB.BB.BB..",
            "..BBBBBBB..",
            "..B.....B..",
        ]

        let colorMap: [Character: NSColor] = [
            "E": earColor,
            "B": bodyColor,
            "O": NSColor.white,
            "W": NSColor.white,
            "K": NSColor.black,
        ]

        for (rowIndex, row) in rows.enumerated() {
            for (colIndex, char) in row.enumerated() {
                guard let color = colorMap[char] else { continue }
                color.setFill()
                let rect = NSRect(
                    x: CGFloat(colIndex) * pixel,
                    y: CGFloat(10 - rowIndex) * pixel,
                    width: pixel,
                    height: pixel
                )
                rect.fill()
            }
        }

        image.unlockFocus()
        return image
    }
}
