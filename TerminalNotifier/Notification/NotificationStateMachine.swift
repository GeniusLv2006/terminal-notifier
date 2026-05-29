import Foundation

enum NotificationState: Equatable {
    case idle
    case detected(count: Int)
    case showing(count: Int)
    case animatingOut
}

enum NotificationEvent {
    case badgeDetected
    case badgeCleared
    case dropAnimationCompleted
    case userDismissed
    case jumpBackCompleted
    case cooldownExpired
    case longWaitElapsed
}

protocol NotificationStateMachineDelegate: AnyObject {
    func stateMachine(_ sm: NotificationStateMachine, didTransitionTo state: NotificationState)
    func stateMachine(_ sm: NotificationStateMachine, shouldShowOverlayWithMessage message: String)
    func stateMachine(_ sm: NotificationStateMachine, shouldUpdateMessage message: String)
    func stateMachineShouldDismissOverlay(_ sm: NotificationStateMachine)
}

class NotificationStateMachine {
    weak var delegate: NotificationStateMachineDelegate?

    private(set) var currentState: NotificationState = .idle
    private var pendingCount: Int = 0
    private var badgeFirstDetectedAt: Date?
    private var isInCooldown: Bool = false
    private var cooldownTimer: Timer?
    private var longWaitTimer: Timer?
    private let messageProvider = MessageProvider()
    private var locale: String { PreferencesManager.shared.resolvedLocale }

    func handleEvent(_ event: NotificationEvent) {
        let oldState = currentState
        switch (currentState, event) {
        case (.idle, .badgeDetected):
            guard !isInCooldown else {
                pendingCount += 1
                return
            }
            pendingCount = 1
            let msg = messageProvider.randomMessage(category: .newNotification, locale: locale)
            currentState = .detected(count: 1)
            badgeFirstDetectedAt = Date()
            delegate?.stateMachine(self, didTransitionTo: currentState)
            delegate?.stateMachine(self, shouldShowOverlayWithMessage: msg)

        case (.idle, .cooldownExpired):
            if pendingCount > 0 {
                let count = pendingCount
                pendingCount = 0
                let msg = messageForShowing(count: count, badgeAge: 0)
                currentState = .detected(count: count)
                badgeFirstDetectedAt = Date()
                delegate?.stateMachine(self, didTransitionTo: currentState)
                delegate?.stateMachine(self, shouldShowOverlayWithMessage: msg)
            }

        case (.detected, .badgeDetected):
            pendingCount += 1

        case (.detected, .dropAnimationCompleted):
            currentState = .showing(count: pendingCount)
            startLongWaitTimer()
            delegate?.stateMachine(self, didTransitionTo: currentState)

        case (.showing, .longWaitElapsed):
            if case .showing(let count) = currentState {
                let msg = messageForShowing(count: count, badgeAge: badgeAge)
                delegate?.stateMachine(self, shouldUpdateMessage: msg)
            }

        case (.showing, .badgeDetected):
            var newCount: Int
            if case .showing(let count) = currentState { newCount = count + 1 }
            else { newCount = 1 }
            currentState = .showing(count: newCount)
            let msg = messageForShowing(count: newCount, badgeAge: badgeAge)
            delegate?.stateMachine(self, shouldUpdateMessage: msg)

        case (.showing, .userDismissed):
            longWaitTimer?.invalidate()
            currentState = .animatingOut
            delegate?.stateMachine(self, didTransitionTo: currentState)
            delegate?.stateMachineShouldDismissOverlay(self)

        case (.animatingOut, .jumpBackCompleted):
            currentState = .idle
            pendingCount = 0
            badgeFirstDetectedAt = nil
            startCooldown()
            delegate?.stateMachine(self, didTransitionTo: currentState)

        case (.idle, .badgeCleared):
            badgeFirstDetectedAt = nil
            pendingCount = 0

        default:
            break
        }
#if DEBUG
        if String(describing: oldState) != String(describing: currentState) {
            print("[SM] \(oldState) + \(event) → \(currentState)")
        } else {
            print("[SM] \(oldState) + \(event) → (no transition)")
        }
#endif
    }

    private func messageForShowing(count: Int, badgeAge: TimeInterval) -> String {
        if count > 1 {
            return messageProvider.mergedMessage(count: count, locale: locale)
        }
        let category: MessageProvider.Category = badgeAge >= Constants.longWaitThreshold
            ? .longWait : .newNotification
        return messageProvider.randomMessage(category: category, locale: locale)
    }

    private var badgeAge: TimeInterval {
        guard let start = badgeFirstDetectedAt else { return 0 }
        return Date().timeIntervalSince(start)
    }

    private func startLongWaitTimer() {
        longWaitTimer?.invalidate()
        let remaining = max(0, Constants.longWaitThreshold - badgeAge)
        longWaitTimer = Timer.scheduledTimer(
            withTimeInterval: remaining,
            repeats: false
        ) { [weak self] _ in
            self?.handleEvent(.longWaitElapsed)
        }
    }

    private func startCooldown() {
        isInCooldown = true
        cooldownTimer?.invalidate()
        let cooldown = PreferencesManager.shared.resolvedCooldown
        cooldownTimer = Timer.scheduledTimer(
            withTimeInterval: cooldown,
            repeats: false
        ) { [weak self] _ in
            self?.isInCooldown = false
            self?.handleEvent(.cooldownExpired)
        }
    }

    func reset() {
        cooldownTimer?.invalidate()
        cooldownTimer = nil
        longWaitTimer?.invalidate()
        longWaitTimer = nil
        isInCooldown = false
        pendingCount = 0
        badgeFirstDetectedAt = nil
        currentState = .idle
    }
}
