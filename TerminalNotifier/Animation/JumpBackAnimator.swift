import QuartzCore

class JumpBackAnimator {

    static let duration: CFTimeInterval = 0.42

    /// Animate a layer from its current position to the menu bar position
    /// using a direct vertical path.
    func animate(layer: CALayer, from currentPos: CGPoint, to targetPos: CGPoint,
                 completion: @escaping () -> Void) {

        let startOffset = currentPos.y - layer.position.y
        let endOffset = targetPos.y - layer.position.y

        let translationAnim = CABasicAnimation(keyPath: "transform.translation.y")
        translationAnim.fromValue = startOffset
        translationAnim.toValue = endOffset
        translationAnim.duration = Self.duration
        translationAnim.timingFunction = CAMediaTimingFunction(name: .easeIn)
        translationAnim.fillMode = .forwards
        translationAnim.isRemovedOnCompletion = false

        let opacityAnim = CABasicAnimation(keyPath: "opacity")
        opacityAnim.fromValue = layer.presentation()?.opacity ?? layer.opacity
        opacityAnim.toValue = 0
        opacityAnim.duration = Self.duration
        opacityAnim.timingFunction = CAMediaTimingFunction(name: .easeIn)
        opacityAnim.fillMode = .forwards
        opacityAnim.isRemovedOnCompletion = false

        let group = CAAnimationGroup()
        group.animations = [translationAnim, opacityAnim]
        group.duration = Self.duration
        group.timingFunction = CAMediaTimingFunction(name: .easeIn)
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock(completion)
        layer.transform = CATransform3DMakeTranslation(0, endOffset, 0)
        layer.opacity = 0
        layer.add(group, forKey: "jumpBack")
        CATransaction.commit()
    }
}
