import AppKit

struct TerminalScreenLocator {
    /// Returns the screen where the target app's frontmost window is, or main screen.
    static func locateScreen(ownerName: String = Constants.terminalAppName) -> NSScreen {
        let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] ?? []

        for window in windowList {
            guard let owner = window[kCGWindowOwnerName as String] as? String,
                  owner == ownerName else { continue }
            guard let boundsDict = window[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
            let bounds = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )
            for screen in NSScreen.screens {
                if screen.frame.intersects(bounds) {
                    return screen
                }
            }
            break
        }

        return NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
    }
}
