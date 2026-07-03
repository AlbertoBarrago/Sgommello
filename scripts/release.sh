#!/bin/bash
# Builds Sgommello.app and packages it into a distributable DMG.
#
# Usage: scripts/release.sh [version]   (default: 0.2.1)
# Output: dist/Sgommello-<version>.dmg
#
# The app is ad-hoc signed: colleagues must right-click > Open the first
# time (Gatekeeper). Camera/Apple Events permissions work per-bundle-id.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-0.2.1}"
APP="dist/Sgommello.app"
DMG="dist/Sgommello-${VERSION}.dmg"
SPARKLE_PUBLIC_KEY="cFHtJGEhaF/cZyO7c8hWpUoyCT2UsuntFhh6qlMx2tk="

if [ -z "${SPARKLE_PUBLIC_KEY}" ] || [ "${SPARKLE_PUBLIC_KEY}" = "REPLACE_WITH_SPARKLE_PUBLIC_ED_KEY" ]; then
    echo "❌ Sparkle public key is not configured."
    echo "   Generate one with Sparkle's generate_keys tool and set SUPublicEDKey."
    exit 1
fi

echo "==> Building release binary"
# Universal binary when the toolchain supports it, native otherwise.
if swift build -c release --arch arm64 --arch x86_64 2>/dev/null; then
    BIN=".build/apple/Products/Release/Sgommello"
else
    echo "    (universal build unavailable, falling back to native arch)"
    swift build -c release
    BIN=".build/release/Sgommello"
fi

echo "==> Assembling ${APP}"
rm -rf dist
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources" "${APP}/Contents/Frameworks"
cp "${BIN}" "${APP}/Contents/MacOS/Sgommello"

SPARKLE_FRAMEWORK=$(find ".build" -path "*/Sparkle.framework" -type d | head -n 1)
if [ -z "${SPARKLE_FRAMEWORK}" ]; then
    echo "❌ Sparkle.framework was not found under .build."
    echo "   Run: swift package resolve"
    exit 1
fi

echo "==> Embedding Sparkle.framework"
ditto "${SPARKLE_FRAMEWORK}" "${APP}/Contents/Frameworks/Sparkle.framework"

cat > "${APP}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>Sgommello</string>
	<key>CFBundleIdentifier</key>
	<string>com.albz.sgommello</string>
	<key>CFBundleName</key>
	<string>Sgommello</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>${VERSION}</string>
	<key>CFBundleVersion</key>
	<string>${VERSION}</string>
	<key>CFBundleIconFile</key>
	<string>Sgommello</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSAppleEventsUsageDescription</key>
	<string>Sgommello mette in pausa la musica (Spotify, Musica) mentre è a schermo e la riprende quando se ne va.</string>
	<key>NSCameraUsageDescription</key>
	<string>Sgommello usa la webcam solo mentre è a schermo, per accorgersi che ti sei alzato e calmarsi.</string>
	<key>SUEnableAutomaticChecks</key>
	<true/>
	<key>SUFeedURL</key>
	<string>https://github.com/AlbertoBarrago/Sgommello/releases/latest/download/appcast.xml</string>
	<key>SUPublicEDKey</key>
	<string>${SPARKLE_PUBLIC_KEY}</string>
	<key>SUScheduledCheckInterval</key>
	<integer>3600</integer>
</dict>
</plist>
PLIST

echo "==> Rendering app icon"
# The ogre emoji rendered at every icns size: no asset files to maintain.
ICONSET="dist/Sgommello.iconset"
mkdir -p "${ICONSET}"
swift - "$ICONSET" <<'SWIFT'
import AppKit
let iconset = CommandLine.arguments[1]
// (points, scale) pairs required by iconutil.
let variants: [(Int, Int)] = [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)]
for (points, scale) in variants {
    let px = points * scale
    let image = NSImage(size: NSSize(width: px, height: px))
    image.lockFocus()
    let glyph = "👹" as NSString
    var fontSize = CGFloat(px)
    // Fit the glyph inside the canvas: emoji glyphs overflow their point size.
    var attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: fontSize)]
    while glyph.size(withAttributes: attrs).width > CGFloat(px), fontSize > 4 {
        fontSize -= max(1, fontSize * 0.05)
        attrs = [.font: NSFont.systemFont(ofSize: fontSize)]
    }
    let size = glyph.size(withAttributes: attrs)
    glyph.draw(at: NSPoint(x: (CGFloat(px) - size.width) / 2,
                           y: (CGFloat(px) - size.height) / 2), withAttributes: attrs)
    image.unlockFocus()
    let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    let png = rep.representation(using: .png, properties: [:])!
    let suffix = scale == 2 ? "@2x" : ""
    try! png.write(to: URL(fileURLWithPath: "\(iconset)/icon_\(points)x\(points)\(suffix).png"))
}
SWIFT
iconutil -c icns "${ICONSET}" -o "${APP}/Contents/Resources/Sgommello.icns"
rm -rf "${ICONSET}"

echo "==> Signing (ad-hoc)"
codesign --force --deep --sign - "${APP}/Contents/Frameworks/Sparkle.framework"
codesign --force --deep --sign - "${APP}"

echo "==> Creating ${DMG}"
STAGING="dist/dmg-staging"
mkdir -p "${STAGING}"
cp -R "${APP}" "${STAGING}/"
ln -s /Applications "${STAGING}/Applications"
hdiutil create -volname "Sgommello" -srcfolder "${STAGING}" -ov -format UDZO "${DMG}" >/dev/null
rm -rf "${STAGING}"

echo "==> Done: ${DMG}"
echo "    Installazione colleghi: apri il DMG, trascina Sgommello in Applications,"
echo "    poi al primo avvio tasto destro > Apri (app non notarizzata)."
