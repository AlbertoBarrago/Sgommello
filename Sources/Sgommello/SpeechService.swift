import AVFoundation

// MARK: - Speech

/// Gives Sgommello an actual voice via the system TTS. One utterance at a
/// time: a new phrase always interrupts the previous one, so punch lines
/// don't queue up behind long rants.
final class SpeechService {
    static let shared = SpeechService()
    private let synthesizer = AVSpeechSynthesizer()

    /// Italian voices installed on this Mac, offered in the settings picker.
    var italianVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "it-IT" }
            .sorted { $0.name < $1.name }
    }

    /// Rocko is Apple's gravelly novelty voice: born to play an ogre.
    var defaultVoice: AVSpeechSynthesisVoice? {
        italianVoices.first { $0.name.contains("Rocko") } ?? italianVoices.first
    }

    func speak(_ text: String, rage: CGFloat = 0) {
        guard AppSettings.shared.voiceEnabled else { return }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        if let id = AppSettings.shared.voiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: id) {
            utterance.voice = voice
        } else {
            utterance.voice = defaultVoice
        }
        // Ogre timbre: low pitch and unhurried delivery. Pinch rage makes
        // him talk higher and faster, like he's genuinely losing it.
        utterance.pitchMultiplier = Float(0.65 + rage * 0.4)
        utterance.rate = Float(0.42 + rage * 0.12)
        utterance.volume = 0.9
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
