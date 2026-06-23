import AppKit
import SwiftUI

class HistoryWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func showHistory(historyManager: NotificationHistoryManager) {
        let historyView = HistoryView(historyManager: historyManager)
        let hostingController = NSHostingController(rootView: historyView)

        if let existing = window {
            existing.contentViewController = hostingController
            existing.center()
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let win = NSWindow(contentViewController: hostingController)
        win.title = NSLocalizedString("Notification History", comment: "")
        win.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.toolbarStyle = .unifiedCompact
        win.tabbingMode = .disallowed
        win.setContentSize(NSSize(width: 620, height: 460))
        win.minSize = NSSize(width: 560, height: 380)
        win.isReleasedWhenClosed = false
        win.delegate = self
        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = win
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
