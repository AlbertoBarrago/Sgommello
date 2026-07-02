import AppKit
import SwiftUI

// MARK: - About view

struct AboutView: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.1"
    }

    var body: some View {
        VStack(spacing: 14) {
            Text("👹")
                .font(.system(size: 82))
                .frame(width: 104, height: 92)

            VStack(spacing: 5) {
                Text("Sgommello")
                    .font(.system(size: 28, weight: .bold))
                Text("Versione \(version)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                Text("Creato da Alberto Barrago")
                    .font(.body.weight(.medium))
                Text("Un promemoria per le pause, un po' aggressivo.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 4)

            Text("© 2026 Alberto Barrago")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 6)
        }
        .multilineTextAlignment(.center)
        .frame(width: 320)
        .padding(.top, 28)
        .padding(.horizontal, 28)
        .padding(.bottom, 24)
    }
}

// MARK: - Window controller

final class AboutWindowController {
    private var window: NSWindow?

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: AboutView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "Informazioni su Sgommello"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
