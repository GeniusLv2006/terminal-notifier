import AppKit

class OverlayWindow: NSWindow {
    var onEscPressed: (() -> Void)?

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onEscPressed?()
        } else {
            super.keyDown(with: event)
        }
    }
}

class OverlayWindowController {
    private var window: OverlayWindow?
    private var contentView: OverlayContentView?
    private let dropAnimator = DropBounceAnimator()
    private let jumpBackAnimator = JumpBackAnimator()
    private var isDismissing = false

    var onDropAnimationComplete: (() -> Void)?
    var onJumpBackComplete: (() -> Void)?
    var onDismissRequested: (() -> Void)?

    func show(on screen: NSScreen,
              message: String) {

        if window != nil { forceClose() }
        isDismissing = false

        let windowRect = screen.frame
        let menuBarY = screen.frame.maxY

        let window = OverlayWindow(
            contentRect: windowRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.isReleasedWhenClosed = false

        window.onEscPressed = { [weak self] in
            self?.onDismissRequested?()
        }

        let contentView = OverlayContentView(
            frame: NSRect(origin: .zero, size: windowRect.size),
            petSize: Constants.defaultPetSize,
            message: message
        )
        contentView.onTap = { [weak self] in
            self?.onDismissRequested?()
        }

        window.contentView = contentView

        self.window = window
        self.contentView = contentView

        prepareDrop(menuBarY: menuBarY, windowRect: windowRect)
        window.makeKeyAndOrderFront(nil)
        window.alphaValue = 1.0

        DispatchQueue.main.async { [weak self] in
            self?.animateDrop(menuBarY: menuBarY, windowRect: windowRect)
        }
    }

    private func prepareDrop(menuBarY: CGFloat, windowRect: NSRect) {
        guard let petView = contentView?.petView else { return }
        petView.wantsLayer = true
        contentView?.layoutSubtreeIfNeeded()

        let finalCenter = OverlayContentView.petCenter(
            in: windowRect.size,
            petSize: Constants.defaultPetSize
        )

        // Start above the window (at menu bar Y, converted to window-local coords)
        let startY = windowRect.height + (menuBarY - windowRect.maxY)

        dropAnimator.prepareInitialState(layer: petView.layer!, from: startY, to: finalCenter.y)
    }

    private func animateDrop(menuBarY: CGFloat, windowRect: NSRect) {
        guard let petView = contentView?.petView else { return }
        petView.wantsLayer = true
        let finalCenter = OverlayContentView.petCenter(
            in: windowRect.size,
            petSize: Constants.defaultPetSize
        )
        let startY = windowRect.height + (menuBarY - windowRect.maxY)

        dropAnimator.animate(
            layer: petView.layer!,
            from: startY,
            to: finalCenter.y,
            completion: { [weak self] in
                self?.onDropAnimationComplete?()
            }
        )
    }

    func updateMessage(_ message: String) {
        contentView?.updateMessage(message)
    }

    func beginDismiss() {
        guard !isDismissing,
              let window,
              let screen = window.screen else {
            forceClose()
            return
        }
        isDismissing = true

        let menuBarY = screen.frame.maxY
        let windowRect = screen.frame
        let targetY = windowRect.height
            + (menuBarY - windowRect.maxY)
            + Constants.defaultPetSize / 2
            + 32

        if let petView = contentView?.petView {
            petView.wantsLayer = true
            let currentPos = currentVisualPosition(for: petView.layer)
                ?? OverlayContentView.petCenter(in: windowRect.size, petSize: Constants.defaultPetSize)

            jumpBackAnimator.animate(
                layer: petView.layer!,
                from: currentPos,
                to: CGPoint(x: currentPos.x, y: targetY),
                completion: { [weak self] in
                    self?.onJumpBackComplete?()
                }
            )
        }

        if let bubble = contentView?.bubbleView {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                bubble.animator().alphaValue = 0
            }
        }
    }

    func forceClose() {
        window?.orderOut(nil)
        window = nil
        contentView = nil
        isDismissing = false
    }

    func close() {
        forceClose()
    }

    private func currentVisualPosition(for layer: CALayer?) -> CGPoint? {
        guard let layer else { return nil }
        let presentation = layer.presentation()
        let basePosition = presentation?.position ?? layer.position
        let transform = presentation?.transform ?? layer.transform
        return CGPoint(
            x: basePosition.x + transform.m41,
            y: basePosition.y + transform.m42
        )
    }
}
