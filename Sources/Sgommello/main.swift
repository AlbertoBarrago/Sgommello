import AppKit

// Entry point: accessory app (menu bar only, no Dock icon).
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
