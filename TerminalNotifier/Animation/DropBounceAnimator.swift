import QuartzCore

class DropBounceAnimator {

    static let duration: CFTimeInterval = 1.2
    private static let damping: CGFloat = 4.0
    private static let frequency: CGFloat = 2.5
    private static let keyframeCount = 72

    func prepareInitialState(layer: CALayer, from startY: CGFloat, to endY: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.transform = CATransform3DMakeTranslation(0, startY - endY, 0)
        layer.opacity = 0
        CATransaction.commit()
    }

    /// Animate a layer into its laid-out position.
    /// The view's frame stays at the final position; only temporary transform and opacity animate.
    func animate(layer: CALayer, from startY: CGFloat, to endY: CGFloat,
                 completion: @escaping () -> Void) {

        let startOffset = startY - endY

        let translationAnim = CAKeyframeAnimation(keyPath: "transform.translation.y")
        translationAnim.values = Self.generateKeyframes(startOffset: startOffset)
        translationAnim.duration = Self.duration
        translationAnim.timingFunction = CAMediaTimingFunction(name: .linear)
        translationAnim.isRemovedOnCompletion = true

        let opacityAnim = CABasicAnimation(keyPath: "opacity")
        opacityAnim.fromValue = 0
        opacityAnim.toValue = 1
        opacityAnim.duration = min(0.28, Self.duration)
        opacityAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        opacityAnim.isRemovedOnCompletion = true

        let group = CAAnimationGroup()
        group.animations = [translationAnim, opacityAnim]
        group.duration = Self.duration
        group.isRemovedOnCompletion = true

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock {
            layer.transform = CATransform3DIdentity
            layer.opacity = 1
            completion()
        }
        layer.transform = CATransform3DIdentity
        layer.opacity = 1
        layer.add(group, forKey: "drop")
        CATransaction.commit()
    }

    private static func generateKeyframes(startOffset: CGFloat) -> [CGFloat] {
        var values: [CGFloat] = []
        for i in 0..<keyframeCount {
            let t = CGFloat(i) / CGFloat(keyframeCount - 1)
            let offset = startOffset * exp(-damping * t) * cos(2 * .pi * frequency * t)
            values.append(i == keyframeCount - 1 ? 0 : offset)
        }
        return values
    }
}
