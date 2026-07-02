# Repository Guidelines

## Project Structure & Module Organization

This is a Swift Package Manager macOS menu bar app. The executable target lives in `Sources/Sgommello/` and is currently composed of single-purpose Swift files:

- `main.swift` starts the accessory `NSApplication`.
- `AppDelegate.swift` wires the status menu, activity monitor, overlay, and settings.
- `ActivityMonitor.swift`, `OverlayController.swift`, `SgommelloView.swift`, and `Crack.swift` contain the core break-reminder behavior and rendering.
- `AppSettings.swift`, `SettingsWindow.swift`, `SpeechService.swift`, `MediaPauser.swift`, and `PresenceMonitor.swift` handle preferences, UI, audio, media apps, and optional webcam presence detection.

Repository-level files include `Package.swift`, `Info.plist`, `README.md`, `CHANGELOG.md`, `docs/index.html`, and `scripts/release.sh`.

## Build, Test, and Development Commands

Run commands from the repository root:

```sh
swift build
swift run
swift test
scripts/release.sh 0.1.0
```

`swift build` compiles the app. `swift run` launches the menu bar app locally. `swift test` is the standard test entry point; the package currently has no test target, so add one before relying on automated coverage. `scripts/release.sh <version>` builds and packages the release DMG.

## Coding Style & Naming Conventions

Use idiomatic Swift 5.9 with 4-space indentation. Keep types in `UpperCamelCase`, methods/properties in `lowerCamelCase`, and constants grouped near the behavior they configure. Prefer small, focused files that match the existing module style. Use `// MARK: -` only for meaningful navigation sections. Avoid adding assets unless necessary; current visuals are procedural.

## Testing Guidelines

There is no `Tests/` directory yet. When adding testable logic, create `Tests/SgommelloTests/` and name files after the feature under test, such as `ActivityMonitorTests.swift`. Favor unit tests for pure timing, settings, crack-generation, and state-transition logic. For UI, media, speech, or camera behavior, document manual macOS verification steps in the pull request.

## Commit & Pull Request Guidelines

Recent history uses concise imperative commit subjects, for example `Translate README to English` and `Disable Jekyll for GitHub Pages`. Follow that style: describe the user-visible change in one short line.

Pull requests should include a clear summary, testing performed (`swift build`, `swift run`, manual checks), and screenshots or screen recordings for visible UI changes. Mention permission-sensitive behavior when touching camera, speech, media control, or `Info.plist`.
