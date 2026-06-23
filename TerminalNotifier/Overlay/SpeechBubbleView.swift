import AppKit

class SpeechBubbleView: NSView {
    var text: String = "" {
        didSet { needsDisplay = true }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    static func preferredSize(for text: String, width: CGFloat) -> NSSize {
        let contentInsets = NSEdgeInsets(top: 16, left: 24, bottom: 16, right: 24)
        let availableWidth = width - contentInsets.left - contentInsets.right
        let attributed = NSAttributedString(string: text, attributes: textAttributes)
        let measured = attributed.boundingRect(
            with: NSSize(width: availableWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let height = max(64, ceil(measured.height) + contentInsets.top + contentInsets.bottom)
        return NSSize(width: width, height: height)
    }

    override func draw(_ dirtyRect: NSRect) {
        let drawingBounds = bounds.insetBy(dx: 8, dy: 6)
        let bubbleRect = drawingBounds
        let bubblePath = NSBezierPath(roundedRect: bubbleRect, xRadius: 18, yRadius: 18)
        let fillColor = NSColor.controlBackgroundColor.withAlphaComponent(0.96)
        let strokeColor = NSColor.separatorColor.withAlphaComponent(0.72)

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(isDarkMode ? 0.36 : 0.16)
        shadow.shadowBlurRadius = 18
        shadow.shadowOffset = NSSize(width: 0, height: -4)
        shadow.set()

        fillColor.setFill()
        bubblePath.fill()
        NSGraphicsContext.restoreGraphicsState()

        strokeColor.setStroke()
        bubblePath.lineWidth = 1
        bubblePath.stroke()

        drawText(in: bubbleRect)
    }

    private func drawText(in bubbleRect: NSRect) {
        let hInset: CGFloat = 24
        let vInset: CGFloat = 15
        let availableWidth = bubbleRect.width - hInset * 2
        let attributed = NSAttributedString(string: text, attributes: Self.textAttributes)
        let drawOptions: NSString.DrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        let measured = attributed.boundingRect(
            with: NSSize(width: availableWidth, height: .greatestFiniteMagnitude),
            options: drawOptions
        )
        let textHeight = min(ceil(measured.height), bubbleRect.height - vInset * 2)
        let textRect = NSRect(
            x: bubbleRect.minX + hInset,
            y: bubbleRect.midY - textHeight / 2,
            width: availableWidth,
            height: textHeight
        )
        attributed.draw(with: textRect, options: drawOptions)
    }

    private var isDarkMode: Bool {
        effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private static var textAttributes: [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = 1.5

        return [
            .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]
    }
}
