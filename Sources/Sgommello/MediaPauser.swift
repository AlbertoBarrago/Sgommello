import AppKit

// MARK: - Media Pauser

/// Pauses known music players when Sgommello shows up and resumes exactly
/// the ones it paused once he leaves. Talks to the apps via Apple Events,
/// and only if they're already running — never launches them.
final class MediaPauser {
    /// Players we know how to drive: display name (for AppleScript) + bundle id.
    private let players: [(name: String, bundleId: String)] = [
        ("Spotify", "com.spotify.client"),
        ("Music", "com.apple.Music")
    ]
    private var pausedPlayers: [String] = []
    private let queue = DispatchQueue(label: "sgommello.media")

    func pauseIfPlaying() {
        let running = runningPlayers()
        queue.async { [weak self] in
            guard let self else { return }
            self.pausedPlayers = running.filter { player in
                // "player state" is supported by both Spotify and Music.
                let state = self.runScript("tell application \"\(player)\" to player state as string")
                guard state == "playing" else { return false }
                self.runScript("tell application \"\(player)\" to pause")
                return true
            }
        }
    }

    /// Resumes only what we paused ourselves: if nothing was playing, nothing starts.
    func resume() {
        queue.async { [weak self] in
            guard let self else { return }
            self.pausedPlayers.forEach { self.runScript("tell application \"\($0)\" to play") }
            self.pausedPlayers = []
        }
    }

    private func runningPlayers() -> [String] {
        let runningIds = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        return players.filter { runningIds.contains($0.bundleId) }.map(\.name)
    }

    @discardableResult
    private func runScript(_ source: String) -> String? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        return result?.stringValue
    }
}
