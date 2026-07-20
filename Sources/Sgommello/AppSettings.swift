import AppKit

// MARK: - Settings (persisted)

final class AppSettings {
    static let shared = AppSettings()
    private let defaults = UserDefaults.standard
    private let triggerMinutesKey = "sgommello.triggerMinutes"
    private let voiceEnabledKey = "sgommello.voiceEnabled"
    private let voiceIdentifierKey = "sgommello.voiceIdentifier"

    private let presenceEnabledKey = "sgommello.presenceEnabled"
    private let breakMinutesKey = "sgommello.breakMinutes"
    private let varenneModeKey = "sgommello.varenneMode"

    /// How long a proper break should last (webcam mode: how long he sleeps).
    var breakMinutes: Double {
        get {
            let stored = defaults.double(forKey: breakMinutesKey)
            return stored > 0 ? stored : 5
        }
        set {
            defaults.set(max(1, newValue), forKey: breakMinutesKey)
        }
    }

    /// Webcam presence detection (off by default: it's a privacy opt-in).
    var presenceEnabled: Bool {
        get { defaults.bool(forKey: presenceEnabledKey) }
        set { defaults.set(newValue, forKey: presenceEnabledKey) }
    }

    /// "Varenne" skin: swaps the ogre for a horse with a goofy gag (off by default).
    var varenneMode: Bool {
        get { defaults.bool(forKey: varenneModeKey) }
        set { defaults.set(newValue, forKey: varenneModeKey) }
    }

    /// Whether Sgommello speaks his phrases out loud (on by default).
    var voiceEnabled: Bool {
        get { defaults.object(forKey: voiceEnabledKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: voiceEnabledKey) }
    }

    /// AVSpeechSynthesisVoice identifier; nil means the built-in default.
    var voiceIdentifier: String? {
        get { defaults.string(forKey: voiceIdentifierKey) }
        set {
            if let newValue {
                defaults.set(newValue, forKey: voiceIdentifierKey)
            } else {
                defaults.removeObject(forKey: voiceIdentifierKey)
            }
        }
    }

    var triggerMinutes: Double {
        get {
            let stored = defaults.double(forKey: triggerMinutesKey)
            return stored > 0 ? stored : 45
        }
        set {
            defaults.set(max(1, newValue), forKey: triggerMinutesKey)
        }
    }

    // Fixed system-sound palette: no user customization, tuned volumes.

    var appearSound: NSSound? {
        NSSound(named: "Funk")
    }

    var glassBreakSound: NSSound? {
        NSSound(named: "Glass")
    }

    /// Low thump layered under the glass break so punches have body.
    var punchSound: NSSound? {
        let sound = NSSound(named: "Basso")
        sound?.volume = 0.9
        return sound
    }

    /// Played when the monster does his umbrella gesture.
    var gestureSound: NSSound? {
        let sound = NSSound(named: "Sosumi")
        sound?.volume = 0.5
        return sound
    }

    /// Growl when the user pinches (clicks) him.
    var pinchSound: NSSound? {
        let sound = NSSound(named: "Frog")
        sound?.volume = 0.8
        return sound
    }

    var stepSounds: [NSSound] {
        // Soft tap-like system sounds, kept quiet: footsteps are ambience,
        // not the main event.
        ["Pop", "Tink", "Bottle"].compactMap { name in
            let sound = NSSound(named: name)
            sound?.volume = 0.3
            return sound
        }
    }
}
