import AppKit
import Sparkle

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let activityMonitor = ActivityMonitor()
    private let overlay = OverlayController()
    private let settingsController = SettingsWindowController()
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        // Template SF Symbol so the icon matches the system menu bar style
        // and adapts to light/dark appearance, like native status items.
        if let icon = NSImage(systemSymbolName: "figure.kickboxing",
                              accessibilityDescription: "Sgommello") {
            icon.isTemplate = true
            statusItem.button?.image = icon
        } else {
            statusItem.button?.title = "👹"
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Sgommello è attivo", action: nil, keyEquivalent: "")
        menu.items.first?.isEnabled = false
        menu.addItem(.separator())

        let pauseItem = NSMenuItem(title: "Metti in pausa", action: #selector(togglePause(_:)), keyEquivalent: "")
        pauseItem.target = self
        menu.addItem(pauseItem)

        let testItem = NSMenuItem(title: "Mostra ora (test)", action: #selector(triggerNow), keyEquivalent: "")
        testItem.target = self
        menu.addItem(testItem)
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Impostazioni…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(title: "Informazioni su Sgommello…", action: #selector(openAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let updateItem = NSMenuItem(
            title: "Controlla aggiornamenti…",
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
            keyEquivalent: ""
        )
        updateItem.target = updaterController
        menu.addItem(updateItem)
        menu.addItem(.separator())

        menu.addItem(withTitle: "Esci", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu

        activityMonitor.onThresholdReached = { [weak self] in
            self?.overlay.show()
        }
        overlay.onDismiss = { [weak self] in
            self?.activityMonitor.resetAfterBreak()
        }
        settingsController.onTestNow = { [weak self] in
            self?.overlay.show()
        }
        settingsController.onIntervalChange = { [weak self] in
            self?.activityMonitor.resetAfterBreak()
        }
        activityMonitor.start()
    }

    @objc private func openSettings() {
        settingsController.show()
    }

    @objc private func openAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Sgommello",
            .applicationIcon: aboutIcon(),
            .credits: NSAttributedString(
                string: "Creato da Alberto Barrago\n© 2026 Alberto Barrago\n\nUn promemoria per le pause, un po' aggressivo.",
                attributes: [.font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)]
            )
        ])
    }

    @objc private func togglePause(_ sender: NSMenuItem) {
        activityMonitor.isPaused.toggle()
        sender.title = activityMonitor.isPaused ? "Riattiva" : "Metti in pausa"
    }

    @objc private func triggerNow() {
        overlay.show()
    }

    private func aboutIcon() -> NSImage {
        if let icon = NSImage(systemSymbolName: "figure.kickboxing",
                              accessibilityDescription: "Sgommello") {
            icon.isTemplate = false
            icon.size = NSSize(width: 128, height: 128)
            return icon
        }

        let image = NSImage(size: NSSize(width: 128, height: 128))
        image.lockFocus()
        NSString(string: "👹").draw(
            in: NSRect(x: 0, y: 8, width: 128, height: 112),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 96),
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.alignment = .center
                    return style
                }()
            ]
        )
        image.unlockFocus()
        return image
    }
}
