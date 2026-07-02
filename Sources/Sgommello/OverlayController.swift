import AppKit

// MARK: - Overlay Controller

final class OverlayController {
    private var windows: [NSWindow] = []
    private var safeZoneTimer: Timer?
    private var timeInSafeZone: TimeInterval = 0
    private let presenceMonitor = PresenceMonitor()
    private let mediaPauser = MediaPauser()
    /// Counts down the configured break while the monster sleeps; firing it
    /// means the break was completed and the overlay can leave on its own.
    private var breakTimer: Timer?
    var onDismiss: (() -> Void)?

    init() {
        presenceMonitor.onUserLeft = { [weak self] in
            self?.startBreak()
        }
        presenceMonitor.onUserReturned = { [weak self] in
            self?.endBreakEarly()
        }
    }

    func show() {
        guard windows.isEmpty else { return }
        // Camera runs only while the monster is on screen (and only if the
        // user opted in from the settings).
        presenceMonitor.start()
        // Silence the soundtrack: his voice deserves the stage. Resumed on dismiss.
        mediaPauser.pauseIfPlaying()
        for screen in NSScreen.screens {
            // No `screen:` parameter on purpose: with it, contentRect gets
            // re-interpreted relative to that screen's origin, double-offsetting
            // the already-global screen.frame and mis-covering secondary
            // monitors. Global coordinates + explicit setFrame cover exactly.
            let window = NSWindow(contentRect: screen.frame, styleMask: .borderless,
                                   backing: .buffered, defer: false)
            window.setFrame(screen.frame, display: true)
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.ignoresMouseEvents = false
            window.hidesOnDeactivate = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            if screen == NSScreen.main {
                let sgView = SgommelloView(frame: NSRect(origin: .zero, size: screen.frame.size))
                sgView.setup(playsAudio: true)
                window.contentView = sgView
            } else {
                // Secondary monitors are simply "switched off": a dark veil
                // with no monster, so all attention goes to the main screen.
                window.backgroundColor = NSColor.black.withAlphaComponent(0.88)
            }
            // orderFrontRegardless (not makeKeyAndOrderFront) so every screen's
            // window actually surfaces even when it isn't the key window —
            // otherwise only the display owning key focus reliably shows it.
            window.orderFrontRegardless()
            // Quick fade-in instead of a hard cut to full-screen darkness.
            window.alphaValue = 0
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                window.animator().alphaValue = 1
            }
            windows.append(window)
        }
        NSApp.activate(ignoringOtherApps: true)

        safeZoneTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.checkSafeZone()
        }
    }

    /// Only the main screen hosts a SgommelloView (and thus a safe zone);
    /// secondary monitors are plain dark veils with nothing to check.
    private func checkSafeZone() {
        let inAnySafeZone = windows.contains { window in
            guard let view = window.contentView as? SgommelloView else { return false }
            let mouseLocation = window.mouseLocationOutsideOfEventStream
            return view.safeZoneRect.contains(mouseLocation)
        }
        if inAnySafeZone {
            timeInSafeZone += 0.2
            if timeInSafeZone >= Config.safeZoneHoldTime {
                dismiss()
                return
            }
        } else {
            timeInSafeZone = 0
        }
        let progress = CGFloat(timeInSafeZone / Config.safeZoneHoldTime)
        windows.forEach { ($0.contentView as? SgommelloView)?.safeZoneProgress = progress }
    }

    /// The user actually stood up: the monster sleeps through the configured
    /// break. If the timer completes, he leaves on his own; if the webcam
    /// sees the user again first, endBreakEarly() cancels it and wakes him.
    private func startBreak() {
        guard !windows.isEmpty, breakTimer == nil else { return }
        let duration = AppSettings.shared.breakMinutes * 60
        windows.forEach { ($0.contentView as? SgommelloView)?.fallAsleep(for: duration) }
        breakTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            guard let self, !self.windows.isEmpty else { return }
            self.breakTimer = nil
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 1.2
                self.windows.forEach { $0.animator().alphaValue = 0 }
            }, completionHandler: { [weak self] in
                self?.dismiss()
            })
        }
    }

    /// Back before the break was over: cancel the countdown, wake him up angry.
    private func endBreakEarly() {
        guard breakTimer != nil else { return }
        breakTimer?.invalidate()
        breakTimer = nil
        windows.forEach { ($0.contentView as? SgommelloView)?.wake() }
    }

    private func dismiss() {
        guard !windows.isEmpty else { return }
        breakTimer?.invalidate()
        breakTimer = nil
        presenceMonitor.stop()
        mediaPauser.resume()
        safeZoneTimer?.invalidate()
        safeZoneTimer = nil
        timeInSafeZone = 0
        windows.forEach {
            ($0.contentView as? SgommelloView)?.stop()
            $0.orderOut(nil)
        }
        windows.removeAll()
        onDismiss?()
    }
}
