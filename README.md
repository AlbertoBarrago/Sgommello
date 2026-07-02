# Sgommello 👹

A menu bar creature for macOS that forces you to take breaks: after too much
uninterrupted screen time, it bursts through the cracked glass of your monitor,
walks all over it, punches it into more cracks and insults you, out loud.

Born as a joke, genuinely useful.

## What it does

- Monitors mouse and keyboard activity. After **45 minutes** of continuous use
  (configurable 5-120) it shows up on the **main display** above every window,
  while the other displays are "switched off" with a dark veil.
- Bursts out of a shattered-glass crack, wanders around, **throws punches that
  crack new portions of the screen** and does the Italian umbrella gesture.
- **Actually speaks** (system TTS, default voice: Italian Rocko, ogre pitch)
  with comically threatening phrases. For now he speaks **Italian only**; he
  insults you in the most beautiful language in the world, deal with it.
- **Pinch it** (click on it) and it gets angry: red dizzy eyes, faster stomping,
  more punching. It cools down on its own in ~30 seconds. Pinching it is
  counterproductive. 🙂
- To chase it away: keep the cursor inside the **green zone for 3 seconds**
  (progress ring included). If you instead go idle for 60 seconds, the activity
  counter resets: a real break is the only true victory.
- When it appears it **pauses your music** (Spotify / Apple Music) and resumes
  it when it leaves; if nothing was playing, nothing starts.
- **Webcam (opt-in)**: if you enable the option, while on screen it checks
  whether you actually stood up; 5 seconds without a face on camera and it
  **falls asleep** for the break duration you chose (1-15 min), with a countdown
  in its speech bubble. Break over: it leaves on its own. Come back early? It
  wakes up angry and starts over. The camera is active **only** while Sgommello
  is visible.

## Requirements

- macOS 13+
- Swift 5.9+ (Xcode or Command Line Tools)

## Build and run

```sh
swift build          # compile
swift run            # start (menu bar icon, no window)
```

From the menu bar (kickboxing icon 🥋):
- **Metti in pausa / Riattiva** suspends monitoring
- **Mostra ora (test)** summons it immediately, for demos or tuning
- **Impostazioni…** timer, break duration, voice on/off, Italian voice picker

## Release (DMG for your colleagues)

```sh
scripts/release.sh 0.1.0   # → dist/Sgommello-0.1.0.dmg
```

The script builds a release binary (universal when possible), assembles
`Sgommello.app` (Info.plist with `LSUIElement`, icon rendered from the 👹
emoji), ad-hoc signs it and packages the DMG with the Applications link.
To install: drag into Applications, then on first launch **right-click → Open**
(the app is not notarized).

The landing page lives in [`docs/`](docs/index.html) and is served by GitHub
Pages: http://albz.it/Sgommello/

## Architecture

```
Sources/Sgommello/
├── main.swift             Entry point (accessory app, menu bar only)
├── AppDelegate.swift      Status menu and component wiring
├── Config.swift           Constants, phrases and one-liners
├── AppSettings.swift      Persisted preferences (UserDefaults) and sound palette
├── ActivityMonitor.swift  Activity/idle detection via CGEventSource
├── Crack.swift            Branching crack model and generation
├── SgommelloView.swift    Monster rendering, state machine, cracks, speech bubble
├── OverlayController.swift Multi-monitor overlay windows and safe zone
├── PresenceMonitor.swift  Webcam + Vision: detects when you stand up
├── SpeechService.swift    Voice via AVSpeechSynthesizer
└── SettingsWindow.swift   Settings window (SwiftUI)
```

Useful details for contributors:
- The monster is **fully procedural** (NSBezierPath/CGContext): no assets.
- Fully propagated cracks are **rasterized into a cache** and blitted; only
  growing ones are redrawn frame by frame.
- The overlay runs at ~33fps on a `Timer`; the monster lives on the main
  display only, secondary displays get a plain dark veil.

Permissions note: the Info.plist with `NSCameraUsageDescription` is embedded
into the bare binary by the linker (see `Package.swift`), so the camera
permission works even without an `.app` bundle. macOS shows the prompt on
first webcam use.

## Roadmap

See [CHANGELOG.md](CHANGELOG.md); in short: launch at login and notarization
for right-click-free installs.
