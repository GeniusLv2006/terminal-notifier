import AppKit

class OverlayContentView: NSView {
    var onTap: (() -> Void)?
    let petView: PetSpriteView
    let bubbleView: SpeechBubbleView

    static func petCenter(in size: NSSize, petSize: CGFloat) -> CGPoint {
        CGPoint(x: size.width / 2, y: size.height / 2)
    }

    init(frame: NSRect, petSize: CGFloat, message: String) {
        self.petView = PetSpriteView(frame: .zero)
        self.bubbleView = SpeechBubbleView(frame: .zero)

        super.init(frame: frame)

        petView.wantsLayer = true
        bubbleView.wantsLayer = true

        addSubview(petView)
        addSubview(bubbleView)
        bubbleView.text = message

        layoutViews(petSize: petSize)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        layoutViews(petSize: petView.frame.width)
    }

    private func layoutViews(petSize: CGFloat) {
        let petCenter = Self.petCenter(in: bounds.size, petSize: petSize)
        let bubbleWidth = min(bounds.width - 64, 300)
        let bubbleSize = SpeechBubbleView.preferredSize(for: bubbleView.text, width: bubbleWidth)
        let bubbleGap: CGFloat = 12
        let petY = petCenter.y - petSize / 2
        let bubbleY = max(24, petY - bubbleGap - bubbleSize.height)

        petView.frame = NSRect(
            x: petCenter.x - petSize / 2,
            y: petY,
            width: petSize,
            height: petSize
        )

        bubbleView.frame = NSRect(
            x: petCenter.x - bubbleWidth / 2,
            y: bubbleY,
            width: bubbleWidth,
            height: bubbleSize.height
        )
    }

    func updateMessage(_ message: String) {
        bubbleView.text = message
        layoutViews(petSize: petView.frame.width)
        bubbleView.needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let localPoint = convert(event.locationInWindow, from: nil)
        if petView.frame.contains(localPoint) || bubbleView.frame.contains(localPoint) {
            onTap?()
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if petView.frame.contains(point) || bubbleView.frame.contains(point) {
            return self
        }
        return nil
    }
}
