import AppKit
import Sparkle

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var statusSummaryItem: NSMenuItem!
    private let activityMonitor = ActivityMonitor()
    private let overlay = OverlayController()
    private let settingsController = SettingsWindowController()
    private let aboutController = AboutWindowController()
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateStatusItemIcon()

        let menu = NSMenu()

        let aboutItem = NSMenuItem(title: "Informazioni", action: #selector(openAbout), keyEquivalent: "")
        aboutItem.target = self
        aboutItem.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: nil)
        menu.addItem(aboutItem)
        menu.addItem(.separator())

        let pauseItem = NSMenuItem(title: "Metti in pausa", action: #selector(togglePause(_:)), keyEquivalent: "")
        pauseItem.target = self
        updatePauseMenuItem(pauseItem)
        menu.addItem(pauseItem)

        let settingsItem = NSMenuItem(title: "Impostazioni", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let updateItem = NSMenuItem(
            title: "Update",
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
            keyEquivalent: ""
        )
        updateItem.target = updaterController
        updateItem.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: nil)
        menu.addItem(updateItem)
        menu.addItem(.separator())

        statusSummaryItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statusSummaryItem.isEnabled = false
        updateStatusSummaryItem()
        menu.addItem(statusSummaryItem)
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

        // Resolve camera permission upfront when presence is enabled, so the
        // TCC prompt shows cleanly at launch instead of stealing focus from the
        // settings window later. If access is refused, the feature can't work,
        // so turn it off to keep the setting honest.
        if AppSettings.shared.presenceEnabled {
            PresenceMonitor.ensureCameraAccess { granted in
                if !granted { AppSettings.shared.presenceEnabled = false }
            }
        }

        // Varenne warps a desktop snapshot: prompt for Screen Recording upfront
        // so the effect works on first appearance (may need a relaunch after
        // granting). Without it the overlay simply falls back to the dark veil.
        if AppSettings.shared.varenneMode {
            _ = CGRequestScreenCaptureAccess()
        }
    }

    @objc private func openSettings() {
        settingsController.show()
    }

    @objc private func openAbout() {
        aboutController.show()
    }

    @objc private func togglePause(_ sender: NSMenuItem) {
        activityMonitor.isPaused.toggle()
        updatePauseMenuItem(sender)
        updateStatusSummaryItem()
        updateStatusItemIcon()
    }

    private func updateStatusItemIcon() {
        let isActive = !activityMonitor.isPaused
        statusItem.button?.image = StatusBarIcon.image(isActive: isActive)
        statusItem.button?.toolTip = isActive ? "Sgommello è attivo" : "Sgommello è in pausa"
    }

    private func updatePauseMenuItem(_ item: NSMenuItem) {
        item.title = activityMonitor.isPaused ? "Riattiva" : "Metti in pausa"
        item.image = NSImage(
            systemSymbolName: activityMonitor.isPaused ? "play.circle" : "pause.circle",
            accessibilityDescription: item.title
        )
    }

    private func updateStatusSummaryItem() {
        statusSummaryItem?.title = activityMonitor.isPaused ? "Sgommello sta riposando" : "Sgommello è in agguato"
        statusSummaryItem?.image = NSImage(
            systemSymbolName: activityMonitor.isPaused ? "moon.zzz" : "flame",
            accessibilityDescription: statusSummaryItem?.title
        )
    }

}
