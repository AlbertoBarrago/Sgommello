import AppKit

// MARK: - Activity Monitor

final class ActivityMonitor {
    private var timer: Timer?
    private(set) var continuousActiveSeconds: TimeInterval = 0
    var onThresholdReached: (() -> Void)?
    var isPaused = false

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        guard !isPaused else { return }
        let idle = idleSeconds()
        if idle >= Config.idleResetThreshold {
            continuousActiveSeconds = 0
            return
        }
        continuousActiveSeconds += 5
        if continuousActiveSeconds >= Config.triggerInterval {
            continuousActiveSeconds = 0
            onThresholdReached?()
        }
    }

    func resetAfterBreak() {
        continuousActiveSeconds = 0
    }

    private func idleSeconds() -> TimeInterval {
        let mouse = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
        let key = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        return min(mouse, key)
    }
}
