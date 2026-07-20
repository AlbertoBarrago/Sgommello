import AppKit
import CoreImage

// MARK: - Overlay View

final class SgommelloView: NSView {
    /// What the monster is currently doing. Transitions happen in step().
    /// `.sleeping` is special: entered/left only via fallAsleep()/wake().
    private enum Action {
        case idle, walking, punching, gesturing, sleeping
    }

    private var action: Action = .idle
    private var actionElapsed: CGFloat = 0
    private var idleDuration: CGFloat = 0.8
    private let punchDuration: CGFloat = 0.9
    private let gestureDuration: CGFloat = 1.4
    /// Set once per punch when the fist connects, so the crack/sound fire once.
    private var punchLanded = false
    /// Screen-shake intensity, decays every frame after a punch.
    private var shake: CGFloat = 0
    /// Accumulated anger from pinches (0...1): reddens the eyes, speeds up
    /// walks and raises the punch odds. Cools down slowly over time.
    private var rageLevel: CGFloat = 0
    /// Timeline instant of the last pinch, drives the dizzy eye-spin.
    private var pinchAt: CGFloat = -10
    /// Timeline instant the nap ends, for the countdown in the bubble.
    private var wakeAt: CGFloat = 0

    private var position: CGPoint = .zero
    private var moveStart: CGPoint = .zero
    private var moveTarget: CGPoint = .zero
    private var moveDuration: CGFloat = 1
    private var facingRight = true
    /// Eased horizontal flip factor (-1...1) so direction changes squash
    /// through zero instead of mirroring instantly.
    private var facingScaleX: CGFloat = 1
    private var phrase: String = Config.phrases.randomElement()!
    private var phraseChangedAt: CGFloat = 0
    private var animationTimer: Timer?
    private var phraseTimer: Timer?
    private var stepSoundTimer: Timer?
    private let safeZoneSize = CGSize(width: 220, height: 140)

    // Impact cracks: the entry burst plus one cluster per landed punch.
    private var cracks: [Crack] = []
    /// Impact centers with birth time, each drawn with concentric rings.
    private var impacts: [(center: CGPoint, bornAt: CGFloat)] = []
    /// Fully-grown cracks are rendered once into this cached image so we
    /// don't re-stroke dozens of paths at 33fps forever. Invalidated when
    /// a punch adds a new cluster.
    private var crackImage: NSImage?
    private var cachedCrackCount = 0
    private var elapsed: CGFloat = 0
    private var appearElapsed: CGFloat = 0

    /// 0...1 fraction of the safe-zone hold time elapsed, fed by the controller.
    var safeZoneProgress: CGFloat = 0

    // Appearance choreography: cracks propagate, then the monster pops out.
    private let crackDuration: CGFloat = 0.35
    private let popDelay: CGFloat = 0.2
    private let popDuration: CGFloat = 0.45

    var safeZoneRect: NSRect {
        NSRect(x: bounds.width - safeZoneSize.width - 40,
               y: 40,
               width: safeZoneSize.width,
               height: safeZoneSize.height)
    }

    private var playsAudio = false
    /// Captured once at setup: swaps the ogre for the Varenne skin.
    private var isVarenne = false
    /// Desktop snapshot warped behind Varenne (nil without Screen Recording).
    private var backdrop: CGImage?
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    /// Extra warp/vibration energy, spiked on each thrust and decaying away.
    private var warpIntensity: CGFloat = 0
    /// Timeline window of the click-triggered "python" extension (Varenne).
    private var snakeStart: CGFloat = -100
    private var snakeEnd: CGFloat = -100
    /// Smoothed lean of the shaft toward the pointer (Varenne, at rest).
    private var willyLean: CGFloat = 0

    /// Roaming phrases for the active skin.
    private var roamPhrases: [String] { isVarenne ? Config.varennePhrases : Config.phrases }
    /// Punch-impact phrases for the active skin.
    private var punchLines: [String] { isVarenne ? Config.varennePunchPhrases : Config.punchPhrases }

    /// Supplies the desktop snapshot to warp behind the Varenne skin. Passing
    /// nil (no Screen Recording permission) falls back to the plain dark veil.
    func setBackdrop(_ image: CGImage?) {
        backdrop = image
    }

    /// The snapshot with an animated bump distortion pulsing from mid-screen,
    /// intensified by each thrust — the "deforming your windows" illusion.
    private func warpedBackdrop() -> NSImage? {
        guard let backdrop else { return nil }
        let base = CIImage(cgImage: backdrop)
        let ext = base.extent
        guard ext.width > 0, bounds.width > 0,
              let filter = CIFilter(name: "CIBumpDistortion") else { return nil }
        let sx = ext.width / bounds.width
        let sy = ext.height / bounds.height
        let pulse = 0.5 + 0.5 * sin(elapsed * 6)
        let scale = min(0.75, 0.1 + warpIntensity * 0.5 + shake * 0.2 + pulse * 0.05)
        filter.setValue(base, forKey: kCIInputImageKey)
        filter.setValue(CIVector(x: bounds.midX * sx, y: bounds.midY * sy), forKey: kCIInputCenterKey)
        filter.setValue(min(ext.width, ext.height) * 0.75, forKey: kCIInputRadiusKey)
        filter.setValue(scale, forKey: kCIInputScaleKey)
        guard let out = filter.outputImage?.cropped(to: ext),
              let cg = ciContext.createCGImage(out, from: ext) else { return nil }
        return NSImage(cgImage: cg, size: bounds.size)
    }

    func setup(playsAudio: Bool = false) {
        self.playsAudio = playsAudio
        isVarenne = AppSettings.shared.varenneMode
        phrase = roamPhrases.randomElement()!
        wantsLayer = true
        // Varenne emerges from the bottom-centre; the ogre from a random spot.
        position = isVarenne ? CGPoint(x: bounds.midX, y: bounds.minY + 30) : randomPoint()
        moveStart = position
        moveTarget = position
        // Stand at the impact point for a beat before the first walk.
        action = .idle
        idleDuration = 1.0
        cracks = Crack.burst(around: position, rays: 8...11, maxLength: 520, bornAt: 0)
        impacts = [(position, 0)]

        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            self?.step()
        }
        // Slow rotation so every line actually gets read before the next one.
        phraseTimer = Timer.scheduledTimer(withTimeInterval: 12, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.action == .sleeping {
                // Silent countdown bubble instead of a barked phrase.
                let remaining = max(1, Int(ceil((self.wakeAt - self.elapsed) / 60)))
                self.phrase = "zzz… mi sveglio tra \(remaining) min"
                self.phraseChangedAt = self.elapsed
                return
            }
            self.phrase = self.roamPhrases.randomElement()!
            self.phraseChangedAt = self.elapsed
            // Varenne is mute: it nags with a flashing alert, not a voice.
            if self.playsAudio && !self.isVarenne {
                SpeechService.shared.speak(self.phrase, rage: self.rageLevel)
            }
        }
        guard playsAudio else { return }
        // Random-interval footsteps so the audio doesn't feel mechanical.
        // Only one instance (the main screen's) plays sound, otherwise every
        // monitor would fire its own overlapping footsteps/appear cue.
        scheduleNextStepSound()
        AppSettings.shared.glassBreakSound?.play()
        AppSettings.shared.appearSound?.play()
        // Opening line spoken once he's out of the crack, not over the glass.
        let openingPhrase = phrase
        if !isVarenne {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                SpeechService.shared.speak(openingPhrase)
            }
        }
    }

    private func scheduleNextStepSound() {
        guard playsAudio else { return }
        let delay = Double.random(in: 0.9...2.0)
        stepSoundTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self else { return }
            AppSettings.shared.stepSounds.randomElement()?.play()
            self.scheduleNextStepSound()
        }
    }

    // MARK: Pinch interaction

    /// Clicking on the monster pinches him: he jolts, his eyes spin and get
    /// redder, and he holds a grudge (rageLevel) that fades slowly.
    override func mouseDown(with event: NSEvent) {
        // Let him sleep: the break countdown is not a minigame.
        guard action != .sleeping else { return }
        // Varenne: any click fires the python extension across the screen.
        if isVarenne {
            rageLevel = min(1, rageLevel + 0.2)
            snakeStart = elapsed
            snakeEnd = elapsed + 4
            shake = max(shake, 0.5)
            warpIntensity = 1
            phrase = punchLines.randomElement()!
            phraseChangedAt = elapsed
            AppSettings.shared.pinchSound?.play()
            return
        }
        let location = convert(event.locationInWindow, from: nil)
        guard hypot(location.x - position.x, location.y - position.y) < Config.spriteSize.width * 0.6 else {
            return
        }
        rageLevel = min(1, rageLevel + 0.34)
        pinchAt = elapsed
        shake = max(shake, 0.5)
        phrase = Config.pinchPhrases.randomElement()!
        phraseChangedAt = elapsed
        // The pinch is local to the clicked screen, so always voice it here.
        AppSettings.shared.pinchSound?.play()
        SpeechService.shared.speak(phrase, rage: rageLevel)
    }

    private func randomPoint() -> CGPoint {
        let margin = Config.spriteSize.width / 2
        let x = CGFloat.random(in: margin...max(margin, bounds.width - margin))
        let y = CGFloat.random(in: margin...max(margin, bounds.height - margin))
        return CGPoint(x: x, y: y)
    }

    // MARK: State machine

    private func beginWalk() {
        action = .walking
        actionElapsed = 0
        moveStart = position
        moveTarget = randomPoint()
        let distance = hypot(moveTarget.x - moveStart.x, moveTarget.y - moveStart.y)
        // Duration derived from distance so long walks don't turn into sprints.
        // Deliberately slow: a heavy ogre lumbering around, not a sprite race.
        // Pinch rage makes him stomp noticeably faster.
        moveDuration = max(1.2, distance / CGFloat.random(in: 55...110)) / (1 + rageLevel * 0.7)
        facingRight = moveTarget.x >= moveStart.x
    }

    /// Picks what to do after finishing the current action. Punches and
    /// gestures only happen after a walk so they land somewhere new each time.
    private func startNextAction() {
        actionElapsed = 0
        punchLanded = false
        // Varenne never roams or auto-punches: it stands put (eyes follow the
        // pointer) and only reacts to a click. The ogre's walk/punch loop is
        // what made it thrash and spike the warp on its own.
        if isVarenne {
            action = .idle
            idleDuration = 3
            return
        }
        let wasWalking = action == .walking
        let roll = Int.random(in: 0..<100)
        if wasWalking {
            // Punching is the main event: over half the stops end in a punch,
            // and an enraged (pinched) monster punches even more.
            switch roll {
            case ..<(55 + Int(rageLevel * 30)):
                action = .punching
            case ..<70:
                action = .gesturing
                if playsAudio {
                    AppSettings.shared.gestureSound?.play()
                }
            case ..<90:
                action = .idle
                idleDuration = CGFloat.random(in: 0.6...1.5)
            default:
                beginWalk()
            }
        } else {
            beginWalk()
        }
    }

    /// The fist connects: crack a new portion of the screen right in front of
    /// the monster, shake the frame, and bark a punch line.
    private func landPunch() {
        // Varenne strikes the screen head-on (center-ish); the ogre punches
        // out to the side of its sprite.
        let impact = isVarenne
            ? CGPoint(x: bounds.midX + CGFloat.random(in: -60...60),
                      y: bounds.midY + CGFloat.random(in: -40...80))
            : CGPoint(x: position.x + facingScaleX * Config.spriteSize.width * 0.45,
                      y: position.y + CGFloat.random(in: -20...30))
        cracks += Crack.burst(around: impact, rays: 5...7, maxLength: 260, bornAt: elapsed)
        impacts.append((impact, elapsed))
        crackImage = nil
        shake = 1
        warpIntensity = 1
        phrase = punchLines.randomElement()!
        phraseChangedAt = elapsed
        if playsAudio {
            // Thump + glass together: the punch has body, then the shatter.
            AppSettings.shared.punchSound?.play()
            AppSettings.shared.glassBreakSound?.play()
            if !isVarenne { SpeechService.shared.speak(phrase, rage: rageLevel) }
        }
    }

    private static func easeInOut(_ t: CGFloat) -> CGFloat {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }

    private func step() {
        elapsed += 0.03
        appearElapsed += 0.03
        shake = max(0, shake - 0.06)
        warpIntensity = max(0, warpIntensity - 0.045)
        // Grudges fade: about 30 seconds from fully enraged back to calm.
        rageLevel = max(0, rageLevel - 0.001)

        // Hold the monster inside the crack until the pop-out completes.
        if appearElapsed >= popDelay + popDuration {
            actionElapsed += 0.03
            switch action {
            case .idle:
                if actionElapsed >= idleDuration { startNextAction() }
            case .walking:
                let t = min(1, actionElapsed / moveDuration)
                let eased = Self.easeInOut(t)
                position = CGPoint(x: moveStart.x + (moveTarget.x - moveStart.x) * eased,
                                   y: moveStart.y + (moveTarget.y - moveStart.y) * eased)
                if t >= 1 { startNextAction() }
            case .punching:
                if !punchLanded, actionElapsed >= punchDuration * 0.4 {
                    punchLanded = true
                    landPunch()
                }
                if actionElapsed >= punchDuration { startNextAction() }
            case .gesturing:
                if actionElapsed >= gestureDuration { startNextAction() }
            case .sleeping:
                break // Naps end only via wake() or the controller's timer.
            }
        }

        // Ease the horizontal flip so turning reads as a squash, not a mirror snap.
        let targetFacing: CGFloat = facingRight ? 1 : -1
        if facingScaleX != targetFacing {
            facingScaleX += min(0.2, abs(targetFacing - facingScaleX)) * (targetFacing > facingScaleX ? 1 : -1)
        }

        needsDisplay = true
    }

    // MARK: Crack rendering

    /// Propagation progress (0...1) of a crack born at a given instant.
    private func crackProgress(bornAt: CGFloat) -> CGFloat {
        min(1, max(0, (elapsed - bornAt) / crackDuration))
    }

    /// Strokes the given cracks and impact rings, each at its own propagation
    /// progress, with a soft halo underneath and a width tapering to the tip.
    private func drawCracks(_ cracksToDraw: [Crack], rings: [(center: CGPoint, bornAt: CGFloat)],
                            into context: CGContext) {
        context.saveGState()
        context.setShadow(offset: .zero, blur: 6,
                          color: NSColor(calibratedRed: 0.75, green: 0.85, blue: 1, alpha: 0.6).cgColor)
        context.setLineCap(.round)
        for crack in cracksToDraw {
            let visibleLength = crack.totalLength * crackProgress(bornAt: crack.bornAt)
            for i in 1..<crack.points.count {
                guard crack.lengths[i - 1] < visibleLength else { break }
                var end = crack.points[i]
                // Clip the currently-growing segment to the visible length.
                if crack.lengths[i] > visibleLength {
                    let t = (visibleLength - crack.lengths[i - 1]) / (crack.lengths[i] - crack.lengths[i - 1])
                    let s = crack.points[i - 1]
                    end = CGPoint(x: s.x + (end.x - s.x) * t, y: s.y + (end.y - s.y) * t)
                }
                let taper = 1 - crack.lengths[i - 1] / crack.totalLength
                context.setLineWidth(max(0.5, crack.baseWidth * taper))
                context.setStrokeColor(NSColor.white.withAlphaComponent(0.55 + 0.3 * taper).cgColor)
                context.move(to: crack.points[i - 1])
                context.addLine(to: end)
                context.strokePath()
            }
        }
        // Impact cores: concentric rings around each punch/entry point.
        context.setLineWidth(1.5)
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.7).cgColor)
        for impact in rings {
            let progress = crackProgress(bornAt: impact.bornAt)
            for radius in [14.0, 26.0, 42.0] {
                let r = radius * progress
                context.strokeEllipse(in: CGRect(x: impact.center.x - r, y: impact.center.y - r,
                                                 width: r * 2, height: r * 2))
            }
        }
        context.restoreGState()
    }

    // MARK: Monster body

    /// Draws the ogre in local coordinates: origin at its center, always
    /// facing +x (the context is pre-flipped for direction). Cartoon anatomy:
    /// stubby legs, blob body, horns, angry face, and two arms that animate
    /// for walking, punching (fist grows toward the viewer) and the classic
    /// "umbrella" gesture.
    private func drawMonster(in context: CGContext, walkPhase: CGFloat,
                             punchT: CGFloat?, gestureT: CGFloat?, sleeping: Bool = false) {
        let w = Config.spriteSize.width
        let h = Config.spriteSize.height
        let skin = NSColor(calibratedRed: 0.58, green: 0.16, blue: 0.2, alpha: 1)
        let skinDark = NSColor(calibratedRed: 0.42, green: 0.1, blue: 0.14, alpha: 1)
        let belly = NSColor(calibratedRed: 0.85, green: 0.62, blue: 0.45, alpha: 1)

        // Legs, alternating with the walk cycle.
        let legLift = walkPhase * 5
        skinDark.setFill()
        NSBezierPath(roundedRect: NSRect(x: -w * 0.24, y: -h * 0.5 + max(0, legLift),
                                         width: w * 0.16, height: h * 0.2),
                     xRadius: 8, yRadius: 8).fill()
        NSBezierPath(roundedRect: NSRect(x: w * 0.08, y: -h * 0.5 + max(0, -legLift),
                                         width: w * 0.16, height: h * 0.2),
                     xRadius: 8, yRadius: 8).fill()

        // Rear arm (far side). During the gesture it slaps the front bicep.
        context.saveGState()
        if gestureT != nil {
            // Forearm crossing the chest for the umbrella gesture.
            skinDark.setFill()
            NSBezierPath(roundedRect: NSRect(x: -w * 0.3, y: -h * 0.05,
                                             width: w * 0.42, height: h * 0.11),
                         xRadius: 7, yRadius: 7).fill()
        } else {
            let swing = sin(elapsed * 5.5) * (walkPhase == 0 ? 0 : 0.25)
            context.rotate(by: swing)
            skinDark.setFill()
            NSBezierPath(ovalIn: NSRect(x: -w * 0.44, y: -h * 0.22,
                                        width: w * 0.14, height: h * 0.3)).fill()
        }
        context.restoreGState()

        // Body blob.
        let bodyRect = NSRect(x: -w * 0.36, y: -h * 0.42, width: w * 0.72, height: h * 0.82)
        skin.setFill()
        NSBezierPath(ovalIn: bodyRect).fill()
        belly.withAlphaComponent(0.9).setFill()
        NSBezierPath(ovalIn: NSRect(x: -w * 0.2, y: -h * 0.36,
                                    width: w * 0.4, height: h * 0.34)).fill()

        // Horns.
        NSColor(calibratedWhite: 0.92, alpha: 1).setFill()
        for side: CGFloat in [-1, 1] {
            let horn = NSBezierPath()
            horn.move(to: NSPoint(x: side * w * 0.16, y: h * 0.32))
            horn.line(to: NSPoint(x: side * w * 0.3, y: h * 0.5))
            horn.line(to: NSPoint(x: side * w * 0.24, y: h * 0.28))
            horn.close()
            horn.fill()
        }

        // Eyes: whites, pupils looking forward, angry brows.
        // Pupils shift yellow → blood red with rage, and spin dizzily for a
        // second right after a pinch. Asleep: just two closed-lid arcs and a
        // tiny relaxed mouth, no brows.
        let talkTime = elapsed - phraseChangedAt
        if sleeping {
            skinDark.setStroke()
            for xCenter: CGFloat in [-0.105, 0.115] {
                let lid = NSBezierPath()
                lid.appendArc(withCenter: NSPoint(x: w * xCenter, y: h * 0.15), radius: w * 0.055,
                              startAngle: 200, endAngle: 340, clockwise: false)
                lid.lineWidth = 4
                lid.stroke()
            }
            NSColor(calibratedRed: 0.2, green: 0.04, blue: 0.06, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: -w * 0.05, y: -h * 0.1,
                                        width: w * 0.1, height: h * 0.05)).fill()
            return
        }
        let whiteTint = NSColor(calibratedRed: 1, green: 1 - rageLevel * 0.25, blue: 1 - rageLevel * 0.35, alpha: 1)
        whiteTint.setFill()
        NSBezierPath(ovalIn: NSRect(x: -w * 0.19, y: h * 0.08, width: w * 0.17, height: h * 0.15)).fill()
        NSBezierPath(ovalIn: NSRect(x: w * 0.03, y: h * 0.08, width: w * 0.17, height: h * 0.15)).fill()

        let dizzyT = elapsed - pinchAt
        var pupilOffset = CGPoint.zero
        if dizzyT < 1.4 {
            // Orbit shrinking to zero: the classic cartoon dazed-eyes spiral.
            let radius = w * 0.028 * (1 - dizzyT / 1.4)
            pupilOffset = CGPoint(x: cos(dizzyT * 11) * radius, y: sin(dizzyT * 11) * radius)
        }
        NSColor(calibratedRed: 0.9, green: 0.75 * (1 - rageLevel), blue: 0.1 * (1 - rageLevel), alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: -w * 0.13 + pupilOffset.x, y: h * 0.1 + pupilOffset.y,
                                    width: w * 0.08, height: h * 0.09)).fill()
        NSBezierPath(ovalIn: NSRect(x: w * 0.1 + pupilOffset.x, y: h * 0.1 + pupilOffset.y,
                                    width: w * 0.08, height: h * 0.09)).fill()
        skinDark.setStroke()
        for (x1, x2): (CGFloat, CGFloat) in [(-0.21, -0.03), (0.03, 0.21)] {
            let brow = NSBezierPath()
            // Inner ends dip down: permanent scowl.
            brow.move(to: NSPoint(x: w * x1, y: h * (x1 < 0 ? 0.27 : 0.22)))
            brow.line(to: NSPoint(x: w * x2, y: h * (x1 < 0 ? 0.22 : 0.27)))
            brow.lineWidth = 5
            brow.stroke()
        }

        // Mouth: wide grin with teeth, chewing motion while a phrase is fresh.
        // Slow chew so the "talking" reads calm, not frantic.
        let mouthOpen = talkTime < 3.5 ? abs(sin(elapsed * 4.5)) * h * 0.06 + h * 0.03 : h * 0.035
        let mouthRect = NSRect(x: -w * 0.18, y: -h * 0.12 - mouthOpen / 2,
                               width: w * 0.36, height: h * 0.06 + mouthOpen)
        NSColor(calibratedRed: 0.2, green: 0.04, blue: 0.06, alpha: 1).setFill()
        NSBezierPath(roundedRect: mouthRect, xRadius: 10, yRadius: 10).fill()
        NSColor.white.setFill()
        for i in 0..<4 {
            let toothX = mouthRect.minX + 8 + CGFloat(i) * (mouthRect.width - 16) / 3 - 4
            NSBezierPath(rect: NSRect(x: toothX, y: mouthRect.maxY - 7, width: 8, height: 7)).fill()
        }

        // Front arm: punch, gesture, or plain swing.
        if let punchT {
            // Fist travels forward and grows: reads as punching "into" the glass.
            var reach: CGFloat = 0
            if punchT < 0.35 {
                reach = -0.1 * Self.easeInOut(punchT / 0.35)
            } else if punchT < 0.55 {
                reach = -0.1 + 1.1 * ((punchT - 0.35) / 0.2)
            } else {
                reach = 1 - Self.easeInOut((punchT - 0.55) / 0.45)
            }
            let fistX = w * (0.3 + 0.28 * reach)
            let fistR = w * (0.09 + 0.08 * max(0, reach))
            skin.setFill()
            NSBezierPath(roundedRect: NSRect(x: w * 0.2, y: -h * 0.02,
                                             width: max(0, fistX - w * 0.2), height: h * 0.1),
                         xRadius: 6, yRadius: 6).fill()
            skinDark.setFill()
            NSBezierPath(ovalIn: NSRect(x: fistX - fistR, y: 0.03 * h - fistR,
                                        width: fistR * 2, height: fistR * 2)).fill()
            // Speed lines behind the fist at full extension.
            if reach > 0.7 {
                NSColor.white.withAlphaComponent(0.7).setStroke()
                for angle in [-0.5, 0.0, 0.5] {
                    let line = NSBezierPath()
                    let a = CGFloat(angle)
                    line.move(to: NSPoint(x: fistX + cos(a) * fistR * 1.2, y: 0.03 * h + sin(a) * fistR * 1.2))
                    line.line(to: NSPoint(x: fistX + cos(a) * fistR * 2, y: 0.03 * h + sin(a) * fistR * 2))
                    line.lineWidth = 3
                    line.stroke()
                }
            }
        } else if gestureT != nil {
            // Umbrella gesture: forearm up, fist shaking at the top.
            let shakeAngle = sin(elapsed * 18) * 0.12
            context.saveGState()
            context.translateBy(x: w * 0.26, y: -h * 0.02)
            context.rotate(by: shakeAngle)
            skin.setFill()
            NSBezierPath(roundedRect: NSRect(x: -w * 0.05, y: 0, width: w * 0.11, height: h * 0.3),
                         xRadius: 7, yRadius: 7).fill()
            skinDark.setFill()
            NSBezierPath(ovalIn: NSRect(x: -w * 0.09, y: h * 0.26, width: w * 0.18, height: w * 0.16)).fill()
            context.restoreGState()
        } else {
            let swing = sin(elapsed * 5.5 + .pi) * (walkPhase == 0 ? 0 : 0.25)
            context.saveGState()
            context.rotate(by: swing)
            skin.setFill()
            NSBezierPath(ovalIn: NSRect(x: w * 0.3, y: -h * 0.22,
                                        width: w * 0.14, height: h * 0.3)).fill()
            context.restoreGState()
        }
    }

    // MARK: Drawing

    // MARK: Varenne body

    /// Draws the "Varenne" skin: a single giant appendage rising slowly and
    /// tremblingly from the bottom edge, screen-anchored (not the roaming
    /// sprite). South Park paper-cutout look — flat fills, thick black
    /// outlines, stiff jointed motion — with enormous hairy base spheres, a
    /// talking face, and an upward thrust on the punch action that drives the
    /// crack burst and the backdrop warp wired elsewhere.
    private func drawWilly(in context: CGContext) {
        let W = bounds.width
        let H = bounds.height
        let flesh = NSColor(calibratedRed: 0.88, green: 0.6, blue: 0.58, alpha: 1)
        let fleshDark = NSColor(calibratedRed: 0.74, green: 0.44, blue: 0.42, alpha: 1)
        let sack = NSColor(calibratedRed: 0.82, green: 0.54, blue: 0.5, alpha: 1)
        let hair = NSColor(calibratedRed: 0.2, green: 0.13, blue: 0.1, alpha: 1)

        // Flat fill + thick black outline: the paper-cutout signature.
        func cutout(_ path: NSBezierPath, _ fill: NSColor, line: CGFloat = 3) {
            fill.setFill(); path.fill()
            NSColor.black.setStroke(); path.lineWidth = line; path.stroke()
        }

        // Slow, straight emergence (~3.5s): rises calmly, no wiggle yet.
        let riseT = Self.easeInOut(min(1, max(0, (appearElapsed - 0.6) / 3.5)))
        // Motion (undulation, lean, mouse-follow) fades in only once it's out.
        let settle = Self.easeInOut(min(1, max(0, (appearElapsed - 3.4) / 1.4)))

        // Punch thrust: wind down slightly, jab up hard, settle back.
        let punchT = action == .punching ? min(1, actionElapsed / punchDuration) : 0
        var jab: CGFloat = 0
        if action == .punching {
            if punchT < 0.35 {
                jab = -0.06 * Self.easeInOut(punchT / 0.35)
            } else if punchT < 0.55 {
                jab = -0.06 + 0.18 * ((punchT - 0.35) / 0.2)
            } else {
                jab = 0.12 * (1 - Self.easeInOut((punchT - 0.55) / 0.45))
            }
        }

        let throb = 1 + sin(elapsed * 3) * 0.03 + warpIntensity * 0.12
        let shaftH = H * 0.48 * throb * (1 + jab) * riseT
        let shaftW = W * 0.1 * (1 + sin(elapsed * 3) * 0.02 + warpIntensity * 0.05)
        let tipR = shaftW * 0.66
        let ballR = shaftW * 0.98 // enormous

        let baseY = -H * 0.02
        context.saveGState()
        context.translateBy(x: W * 0.5, y: baseY)

        // Enormous hairy sack: two big cutout spheres, bristling with hair.
        for side in [-1.0, 1.0] as [CGFloat] {
            let cx = side * ballR * 0.72
            let cy = ballR * 0.3 * riseT
            cutout(NSBezierPath(ovalIn: NSRect(x: cx - ballR, y: cy - ballR,
                                               width: ballR * 2, height: ballR * 2)), sack)
            // Long cartoon strands sprouting thick around the lower two-thirds
            // of the sphere, each undulating along its length like underwater.
            hair.setStroke()
            let count = 60
            for i in 0..<count {
                // Cover a wide arc (past the equator) for a full bushy look.
                let a = CGFloat.pi * (0.82 + 1.36 * (CGFloat(i) / CGFloat(count - 1)))
                let r0 = ballR * (0.9 + 0.08 * abs(sin(CGFloat(i) * 2.3)))
                let sx = cx + cos(a) * r0, sy = cy + sin(a) * r0
                let len = ballR * (0.6 + 0.55 * abs(sin(CGFloat(i) * 1.9)))
                let perpX = -sin(a), perpY = cos(a)
                let strand = NSBezierPath()
                strand.lineWidth = 2.2
                strand.lineCapStyle = .round
                strand.move(to: NSPoint(x: sx, y: sy))
                let steps = 7
                for s in 1...steps {
                    let f = CGFloat(s) / CGFloat(steps)
                    let along = len * f
                    let wave = sin(elapsed * 3 + CGFloat(i) * 0.8 + f * 3.6) * (len * 0.2) * f
                    strand.line(to: NSPoint(x: sx + cos(a) * along + perpX * wave,
                                            y: sy + sin(a) * along + perpY * wave))
                }
                strand.stroke()
            }
        }

        // Python mode: a click extends it across the screen in a travelling
        // snake wave; it eases back on its own after ~4s.
        // Clamp the eased inputs to [0,1]: easeInOut is only defined there and
        // blows up for out-of-range values (a huge idle `snakeEnd` otherwise
        // yields a giant `snake`, launching the shaft off-screen at rest).
        var snake: CGFloat = 0
        if elapsed < snakeEnd {
            snake = Self.easeInOut(min(1, max(0, (elapsed - snakeStart) / 1.2)))
        } else {
            snake = 1 - Self.easeInOut(min(1, max(0, (elapsed - snakeEnd) / 1.1)))
        }

        // The glans + face. It's mute, so no moving mouth: eyes track the
        // pointer via (lookX, lookY) and it wears a fixed mocking grin.
        func drawHead(atX hx: CGFloat, atY hy: CGFloat, lookX: CGFloat, lookY: CGFloat) {
            cutout(NSBezierPath(ovalIn: NSRect(x: hx - tipR * 1.08, y: hy - tipR * 0.7,
                                               width: tipR * 2.16, height: tipR * 1.95)), fleshDark)
            let faceY = hy + tipR * 0.6
            if action == .sleeping {
                NSColor.black.setStroke()
                for ex in [-tipR * 0.42, tipR * 0.42] {
                    let lid = NSBezierPath()
                    lid.lineWidth = 2.5
                    lid.move(to: NSPoint(x: hx + ex - tipR * 0.16, y: faceY))
                    lid.line(to: NSPoint(x: hx + ex + tipR * 0.16, y: faceY))
                    lid.stroke()
                }
            } else {
                let eyeR = tipR * 0.17
                for ex in [-tipR * 0.42, tipR * 0.42] {
                    let ecx = hx + ex, ecy = faceY
                    // White sclera.
                    let sclera = NSBezierPath(ovalIn: NSRect(x: ecx - eyeR, y: ecy - eyeR,
                                                             width: eyeR * 2, height: eyeR * 2))
                    NSColor(calibratedWhite: 0.96, alpha: 1).setFill(); sclera.fill()
                    NSColor.black.setStroke(); sclera.lineWidth = 1.5; sclera.stroke()
                    // Pupil slides toward the pointer, reddening with rage.
                    let pr = eyeR * 0.52
                    let px = ecx + lookX * (eyeR - pr), py = ecy + lookY * (eyeR - pr)
                    NSColor(calibratedRed: 0.1 + rageLevel * 0.85, green: 0.08, blue: 0.08, alpha: 1).setFill()
                    NSBezierPath(ovalIn: NSRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)).fill()
                }
            }
            // Mocking grin: an asymmetric curve hooking up on one side.
            if action != .sleeping {
                let my = hy + tipR * 0.08
                let grin = NSBezierPath()
                grin.lineWidth = 3
                grin.lineCapStyle = .round
                grin.move(to: NSPoint(x: hx - tipR * 0.38, y: my))
                grin.curve(to: NSPoint(x: hx + tipR * 0.44, y: my + tipR * 0.16),
                           controlPoint1: NSPoint(x: hx - tipR * 0.05, y: my - tipR * 0.24),
                           controlPoint2: NSPoint(x: hx + tipR * 0.22, y: my - tipR * 0.06))
                NSColor.black.setStroke(); grin.stroke()
            }
        }

        // One unified curved tube for both states, so it never breaks into
        // flat bands: at rest it stands tall and bends its tip toward the
        // pointer with a gentle undulation; the click blends it into a long
        // travelling snake wave. Head is kept on screen by bounding the lean
        // and capping the length.
        let mouseView = convert(window?.mouseLocationOutsideOfEventStream ?? NSPoint(x: W * 0.5, y: H * 0.7),
                                from: nil)
        let mLocalX = mouseView.x - W * 0.5
        let mLocalY = max(80, mouseView.y - baseY)
        // The body only leans a hair toward the pointer; the eyes do the real
        // following. Heavily smoothed so it never dances around.
        let targetLean = max(-0.12, min(0.12, mLocalX / (W * 0.5))) * (1 - snake) * settle
        willyLean += (targetLean - willyLean) * 0.05
        let lean = willyLean

        let maxTop = H * 0.82 - tipR * 1.6
        let lengthRest = min(H * 0.5 * throb * riseT, maxTop)
        let lengthPython = min(shaftH + hypot(W, H) * 1.5, maxTop)
        let L = lengthRest + (lengthPython - lengthRest) * snake
        // No undulation during the calm emergence; it fades in with `settle`.
        let ampRest = shaftW * 0.55 * settle
        let ampPython = W * 0.32
        let amp = ampRest + (ampPython - ampRest) * snake
        let waves = 1.1 + snake * 1.0
        let speed = 1.3 + snake * 0.7

        let tube = NSBezierPath()
        tube.lineJoinStyle = .round
        tube.lineCapStyle = .round
        tube.move(to: .zero)
        var tip = NSPoint.zero
        let steps = 44
        for k in 1...steps {
            let t = CGFloat(k) / CGFloat(steps)
            // Spine curves toward the pointer; wave rides on top, damped at tip.
            let bend = sin(t * .pi / 2) * lean
            let along = t * L
            let wave = amp * sin(t * waves * .pi - elapsed * speed) * (0.2 + 0.8 * t) * (1 - pow(t, 3))
            tip = NSPoint(x: sin(bend) * along + wave, y: cos(bend) * along)
            tube.line(to: tip)
        }
        NSColor.black.setStroke(); tube.lineWidth = shaftW + 5; tube.stroke()
        flesh.setStroke(); tube.lineWidth = shaftW; tube.stroke()
        let lookDX = mLocalX - tip.x, lookDY = mLocalY - tip.y
        let lookLen = max(1, hypot(lookDX, lookDY))
        drawHead(atX: tip.x, atY: tip.y, lookX: lookDX / lookLen, lookY: lookDY / lookLen)

        context.restoreGState()

        // No voice, no bubble: Varenne nags with a flashing alert banner.
        if riseT > 0.4 {
            drawFlashingAlert()
        }
    }

    /// Big blinking "ALZATI O TI SPANO!" banner for the mute Varenne skin.
    private func drawFlashingAlert() {
        let on = sin(elapsed * 6) > -0.35 // mostly on, brief blink-off
        let alpha: CGFloat = on ? 1 : 0.12
        let text = "ALZATI O TI SPANO!" as NSString
        let fontSize = min(56, bounds.width * 0.06)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.9 * alpha)
        shadow.shadowBlurRadius = 8
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .heavy),
            .foregroundColor: NSColor(calibratedRed: 1, green: 0.16, blue: 0.16, alpha: alpha),
            .strokeColor: NSColor.black.withAlphaComponent(alpha),
            .strokeWidth: -4,
            .shadow: shadow
        ]
        let size = text.size(withAttributes: attrs)
        let x = (bounds.width - size.width) / 2
        let y = bounds.height * 0.84
        let plate = NSRect(x: x - 28, y: y - 14, width: size.width + 56, height: size.height + 24)
        NSColor.black.withAlphaComponent(0.45 * alpha).setFill()
        NSBezierPath(roundedRect: plate, xRadius: 14, yRadius: 14).fill()
        text.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
    }

    /// Renders the phrase bubble anchored above a point, wrapping and clamping
    /// it inside the screen. Shared by the monster and the Varenne skins.
    private func drawSpeechBubble(anchorX: CGFloat, bottomY: CGFloat) {
        let phraseT = min(1, (elapsed - phraseChangedAt) / 0.25)
        let bubbleAlpha = 0.85 * phraseT
        let bubbleRise = (1 - Self.easeInOut(phraseT)) * -8
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let bubbleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 22),
            .foregroundColor: NSColor.white.withAlphaComponent(phraseT),
            .paragraphStyle: paragraph
        ]
        let maxTextWidth = min(320, bounds.width - 80)
        let textRect = (phrase as NSString).boundingRect(
            with: NSSize(width: maxTextWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: bubbleAttrs)
        let padding: CGFloat = 14
        var bubbleX = anchorX - textRect.width / 2 - padding
        bubbleX = min(max(bubbleX, 10), bounds.width - textRect.width - padding * 2 - 10)
        let bubbleRect = NSRect(x: bubbleX,
                                 y: bottomY + bubbleRise,
                                 width: textRect.width + padding * 2,
                                 height: textRect.height + padding)
        let path = NSBezierPath(roundedRect: bubbleRect, xRadius: 12, yRadius: 12)
        let tailX = min(max(anchorX, bubbleRect.minX + 16), bubbleRect.maxX - 16)
        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: tailX - 8, y: bubbleRect.minY))
        tail.line(to: NSPoint(x: tailX + 8, y: bubbleRect.minY))
        tail.line(to: NSPoint(x: tailX, y: bubbleRect.minY - 12))
        tail.close()
        NSColor(calibratedWhite: 0.1, alpha: bubbleAlpha).setFill()
        path.fill()
        tail.fill()
        (phrase as NSString).draw(
            with: NSRect(x: bubbleRect.minX + padding, y: bubbleRect.minY + padding / 2,
                         width: textRect.width, height: textRect.height),
            options: [.usesLineFragmentOrigin],
            attributes: bubbleAttrs)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Punch screen-shake: jolt the whole scene, decaying over a few frames.
        if shake > 0 {
            context.translateBy(x: sin(elapsed * 90) * shake * 9,
                                y: cos(elapsed * 70) * shake * 6)
        }
        // Varenne: the scene trembles only while the screen is being warped,
        // not at rest (a constant jitter read as "bouncing").
        if isVarenne, warpIntensity > 0.01 {
            let amp = warpIntensity * 6
            context.translateBy(x: sin(elapsed * 44) * amp, y: cos(elapsed * 37) * amp * 0.8)
        }

        // Varenne shows the (warped) desktop snapshot behind the appendage;
        // otherwise the classic dark veil. If the snapshot is missing (no
        // Screen Recording permission), fall back to the veil so it degrades.
        if isVarenne, let warped = warpedBackdrop() {
            // Draw it slightly crooked and oversized so the real windows look
            // bent, without exposing the transparent corners under rotation.
            context.saveGState()
            let tilt = sin(elapsed * 1.3) * 0.015 + warpIntensity * sin(elapsed * 30) * 0.012
            context.translateBy(x: bounds.midX, y: bounds.midY)
            context.rotate(by: tilt)
            context.scaleBy(x: 1.07, y: 1.07)
            context.translateBy(x: -bounds.midX, y: -bounds.midY)
            warped.draw(in: bounds, from: .zero, operation: .copy, fraction: 1)
            context.restoreGState()
            NSColor.black.withAlphaComponent(0.18).setFill()
            bounds.insetBy(dx: -20, dy: -20).fill()
        } else {
            NSColor.black.withAlphaComponent(0.35).setFill()
            bounds.insetBy(dx: -20, dy: -20).fill()
        }

        // Cracks: fully-grown ones come from the cached raster; still-growing
        // ones (entry burst or a fresh punch) are stroked live on top.
        let grown = cracks.filter { crackProgress(bornAt: $0.bornAt) >= 1 }
        let growing = cracks.filter { crackProgress(bornAt: $0.bornAt) < 1 }
        let grownRings = impacts.filter { crackProgress(bornAt: $0.bornAt) >= 1 }
        let growingRings = impacts.filter { crackProgress(bornAt: $0.bornAt) < 1 }
        if crackImage == nil || cachedCrackCount != grown.count {
            let image = NSImage(size: bounds.size)
            image.lockFocus()
            if let cacheContext = NSGraphicsContext.current?.cgContext {
                drawCracks(grown, rings: grownRings, into: cacheContext)
            }
            image.unlockFocus()
            crackImage = image
            cachedCrackCount = grown.count
        }
        crackImage?.draw(in: bounds)
        if !growing.isEmpty || !growingRings.isEmpty {
            drawCracks(growing, rings: growingRings, into: context)
        }

        // Varenne skin: a screen-anchored appendage, not the roaming sprite.
        if isVarenne {
            drawWilly(in: context)
            drawSafeZone()
            return
        }

        // Pop-out: the monster bursts through the crack with an overshoot,
        // then walks with a step-synced bob, squash & stretch, and a shadow.
        let popT = min(1, max(0, (appearElapsed - popDelay) / popDuration))
        // easeOutBack: overshoots past 1 and settles, sells the "burst" feel.
        let c1: CGFloat = 1.7
        let popScale = popT == 0 ? 0 : 1 + (c1 + 1) * pow(popT - 1, 3) + c1 * pow(popT - 1, 2)
        guard popScale > 0.01 else { return }

        let isWalking = action == .walking && popT >= 1
        let isSleeping = action == .sleeping
        // Step cadence matched to the slower stride.
        let bobPhase = sin(elapsed * 5.5)
        let bob = isWalking ? abs(bobPhase) * 9 : sin(elapsed * 2.5) * 2
        // Squash on landing, stretch at the top of each hop.
        // Asleep: slow, deep breathing instead of the walk bounce.
        var squashY = isWalking ? 1 + bobPhase * 0.06 : 1 + sin(elapsed * 2.5) * 0.015
        if isSleeping {
            squashY = 0.92 + sin(elapsed * 1.6) * 0.04
        }
        let stretchX = 2 - squashY

        let w = Config.spriteSize.width
        let h = Config.spriteSize.height

        // Punch choreography: lean back on wind-up, lunge forward on strike.
        let punchT = action == .punching ? min(1, actionElapsed / punchDuration) : 0
        var punchLean: CGFloat = 0
        var punchLunge: CGFloat = 0
        if action == .punching {
            if punchT < 0.35 {
                punchLean = -0.12 * Self.easeInOut(punchT / 0.35)
            } else if punchT < 0.55 {
                let strike = (punchT - 0.35) / 0.2
                punchLean = -0.12 + 0.24 * strike
                punchLunge = strike * 0.14
            } else {
                let recover = (punchT - 0.55) / 0.45
                punchLean = 0.12 * (1 - Self.easeInOut(recover))
                punchLunge = 0.14 * (1 - Self.easeInOut(recover))
            }
        }

        // Ground shadow: widens and darkens as the monster comes down from a hop.
        let shadowSpread = isWalking ? 1 - abs(bobPhase) * 0.25 : 1
        let shadowRect = NSRect(x: position.x - w * 0.38 * shadowSpread * popScale,
                                y: position.y - h * 0.52,
                                width: w * 0.76 * shadowSpread * popScale,
                                height: h * 0.14)
        NSColor.black.withAlphaComponent(0.35 * shadowSpread).setFill()
        NSBezierPath(ovalIn: shadowRect).fill()

        context.saveGState()
        context.translateBy(x: position.x, y: position.y + (isSleeping ? -h * 0.08 : bob))
        // Slight lean into the walking direction, stronger lean when punching,
        // slumped over to one side while sleeping.
        if isWalking {
            context.rotate(by: -facingScaleX * 0.06)
        }
        if isSleeping {
            context.rotate(by: facingScaleX * 0.18)
        }
        if punchLean != 0 {
            context.rotate(by: -facingScaleX * punchLean)
        }
        let lungeScale = 1 + punchLunge
        context.scaleBy(x: popScale * stretchX * facingScaleX * lungeScale,
                        y: popScale * squashY * lungeScale)
        drawMonster(in: context, walkPhase: isWalking ? bobPhase : 0,
                    punchT: action == .punching ? punchT : nil,
                    gestureT: action == .gesturing ? min(1, actionElapsed / gestureDuration) : nil,
                    sleeping: isSleeping)
        context.restoreGState()

        // Floating Zzz drifting up from his head while he sleeps.
        if isSleeping {
            for i in 0..<3 {
                let t = (elapsed * 0.35 + CGFloat(i) / 3).truncatingRemainder(dividingBy: 1)
                let zAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.boldSystemFont(ofSize: 16 + t * 14),
                    .foregroundColor: NSColor.white.withAlphaComponent(0.8 * (1 - t))
                ]
                ("z" as NSString).draw(at: NSPoint(x: position.x + w * 0.3 + t * 46,
                                                    y: position.y + h * 0.3 + t * 60),
                                       withAttributes: zAttrs)
            }
        }

        // Speech bubble appears only once the monster is fully out.
        guard popT >= 1 else {
            drawSafeZone()
            return
        }

        // Speech bubble, anchored above the monster's head.
        drawSpeechBubble(anchorX: position.x,
                         bottomY: position.y + Config.spriteSize.height / 2 + 14)

        drawSafeZone()
    }

    private func drawSafeZone() {
        let zone = safeZoneRect
        NSColor.systemGreen.withAlphaComponent(0.25).setFill()
        NSBezierPath(roundedRect: zone, xRadius: 16, yRadius: 16).fill()
        NSColor.systemGreen.setStroke()
        let border = NSBezierPath(roundedRect: zone, xRadius: 16, yRadius: 16)
        border.lineWidth = 2
        border.stroke()
        let label = "resta qui 3s\nper scacciarlo" as NSString
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 16),
            .foregroundColor: NSColor.white
        ]
        label.draw(in: zone.insetBy(dx: 10, dy: 10), withAttributes: labelAttrs)

        // Hold-progress ring so the user sees how long is left before dismissal.
        if safeZoneProgress > 0 {
            let center = NSPoint(x: zone.maxX - 28, y: zone.minY + 28)
            let ring = NSBezierPath()
            ring.appendArc(withCenter: center, radius: 14, startAngle: 90,
                           endAngle: 90 - 360 * safeZoneProgress, clockwise: true)
            ring.lineWidth = 4
            ring.lineCapStyle = .round
            NSColor.white.setStroke()
            ring.stroke()
        }
    }

    /// The webcam saw the user stand up: he curls up and sleeps through the
    /// break, showing a countdown. The controller owns the wake-up timer.
    func fallAsleep(for duration: TimeInterval) {
        rageLevel = 0
        action = .sleeping
        actionElapsed = 0
        wakeAt = elapsed + CGFloat(duration)
        phrase = Config.sleepPhrases.randomElement()!
        phraseChangedAt = elapsed
        if playsAudio && !isVarenne {
            SpeechService.shared.speak(phrase)
        }
    }

    /// The user came back before the break was over: he wakes up annoyed
    /// and goes right back to harassing.
    func wake() {
        guard action == .sleeping else { return }
        rageLevel = min(1, rageLevel + 0.34)
        action = .idle
        actionElapsed = 0
        idleDuration = 1.0
        shake = max(shake, 0.4)
        phrase = Config.wakePhrases.randomElement()!
        phraseChangedAt = elapsed
        if playsAudio && !isVarenne {
            SpeechService.shared.speak(phrase, rage: rageLevel)
        }
    }

    func stop() {
        if playsAudio {
            SpeechService.shared.stop()
        }
        animationTimer?.invalidate()
        animationTimer = nil
        phraseTimer?.invalidate()
        phraseTimer = nil
        stepSoundTimer?.invalidate()
        stepSoundTimer = nil
    }
}
