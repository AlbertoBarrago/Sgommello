import SwiftUI
import AppKit

// MARK: - Settings model

/// Observable bridge over AppSettings so SwiftUI reacts to changes.
/// Writes go straight through to the persisted store.
final class SettingsModel: ObservableObject {
    @Published var triggerMinutes: Double {
        didSet { AppSettings.shared.triggerMinutes = triggerMinutes }
    }
    @Published var breakMinutes: Double {
        didSet { AppSettings.shared.breakMinutes = breakMinutes }
    }
    @Published var voiceEnabled: Bool {
        didSet { AppSettings.shared.voiceEnabled = voiceEnabled }
    }
    @Published var voiceIdentifier: String {
        didSet { AppSettings.shared.voiceIdentifier = voiceIdentifier }
    }
    @Published var presenceEnabled: Bool {
        didSet {
            AppSettings.shared.presenceEnabled = presenceEnabled
            // Ask for camera access right away, so the permission prompt
            // shows here in the settings and not mid-appearance later.
            if presenceEnabled {
                PresenceMonitor.requestPermissionIfNeeded()
            }
        }
    }

    /// Installed Italian voices for the picker (identifier + display name).
    let voices: [(id: String, name: String)]

    /// Fired when the trigger interval changes, so the app can reset its activity counter.
    var onIntervalChange: (() -> Void)?

    init() {
        triggerMinutes = AppSettings.shared.triggerMinutes
        breakMinutes = AppSettings.shared.breakMinutes
        voiceEnabled = AppSettings.shared.voiceEnabled
        presenceEnabled = AppSettings.shared.presenceEnabled
        voices = SpeechService.shared.italianVoices.map { ($0.identifier, $0.name) }
        voiceIdentifier = AppSettings.shared.voiceIdentifier
            ?? SpeechService.shared.defaultVoice?.identifier ?? ""
    }

    func previewVoice() {
        SpeechService.shared.speak(Config.phrases.randomElement()!)
    }
}

// MARK: - Settings view

struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    var onTestNow: () -> Void

    var body: some View {
        Form {
            Section("Timer") {
                VStack(alignment: .leading, spacing: 4) {
                    Slider(value: $model.triggerMinutes, in: 5...120, step: 5) {
                        Text("Compare dopo")
                    } minimumValueLabel: {
                        Text("5m")
                    } maximumValueLabel: {
                        Text("2h")
                    }
                    .onChange(of: model.triggerMinutes) { _ in
                        model.onIntervalChange?()
                    }
                    Text("Sgommello arriva dopo \(Int(model.triggerMinutes)) minuti di attività continua.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Slider(value: $model.breakMinutes, in: 1...15, step: 1) {
                        Text("Durata pausa")
                    } minimumValueLabel: {
                        Text("1m")
                    } maximumValueLabel: {
                        Text("15m")
                    }
                    Text("Con la webcam attiva: se ti alzi, dorme per \(Int(model.breakMinutes)) minuti e poi se ne va da solo. Se torni prima, si sveglia.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Voce") {
                Toggle("Abilita voce", isOn: $model.voiceEnabled)
                Picker("Voce", selection: $model.voiceIdentifier) {
                    ForEach(model.voices, id: \.id) { voice in
                        Text(voice.name).tag(voice.id)
                    }
                }
                .disabled(!model.voiceEnabled)
                Button {
                    model.previewVoice()
                } label: {
                    Label("Ascolta un esempio", systemImage: "speaker.wave.2.fill")
                }
                .disabled(!model.voiceEnabled)
            }

            Section("Webcam") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Si calma se ti alzi davvero", isOn: $model.presenceEnabled)
                    Text("Usa la webcam solo mentre Sgommello è a schermo: se non ti vede per 5 secondi, saluta e se ne va da solo.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                HStack {
                    Spacer()
                    Button {
                        onTestNow()
                    } label: {
                        Label("Prova Sgommello ora", systemImage: "play.fill")
                    }
                    .controlSize(.large)
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Window controller

/// Owns the single settings window; recreated lazily and reused on reopen.
final class SettingsWindowController {
    private var window: NSWindow?
    private let model = SettingsModel()
    var onTestNow: (() -> Void)?
    var onIntervalChange: (() -> Void)? {
        didSet { model.onIntervalChange = onIntervalChange }
    }

    func show() {
        if window == nil {
            let view = SettingsView(model: model) { [weak self] in self?.onTestNow?() }
            let hosting = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: hosting)
            window.title = "Impostazioni Sgommello"
            window.styleMask = [.titled, .closable, .miniaturizable]
            // Keep the window alive on close so state and position survive reopening.
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        // Accessory apps don't get focus automatically: activate explicitly.
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
