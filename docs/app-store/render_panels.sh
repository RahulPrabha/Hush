#!/bin/bash
# Renders the Hush panel offscreen, one PNG per screenshot, into a directory
# (default: ./captures). Nothing is read from the screen. The files are inputs
# for make_screenshots.py and are not committed.
#
# Usage: docs/app-store/render_panels.sh [out-dir]
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/../../Hush/Hush"
OUT="${1:-captures}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

APP="$WORK/PanelRenderer.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$OUT"

# Compile the app's own views and audio model with the offscreen entry point
# (top-level code must live in a file named main.swift).
cp "$HERE/render_panel.swift" "$WORK/main.swift"
swiftc -O -o "$APP/Contents/MacOS/render_panel" \
  "$WORK/main.swift" \
  "$SRC/ContentView.swift" "$SRC/AudioEngine.swift" \
  "$SRC/NoiseGenerator.swift" "$SRC/LaunchAtLogin.swift"

# The app's String Catalog, compiled to .lproj folders so the views localize.
xcrun xcstringstool compile --output-directory "$APP/Contents/Resources" "$SRC/Localizable.xcstrings"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>ca.prabhakar.hush.panel-renderer</string>
  <key>CFBundleExecutable</key><string>render_panel</string>
  <key>CFBundleName</key><string>PanelRenderer</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key>
  <array><string>en</string><string>de</string><string>es</string><string>fr</string><string>it</string>
  <string>ja</string><string>ko</string><string>pt-BR</string><string>zh-Hans</string></array>
</dict></plist>
PLIST
codesign --force --sign - "$APP" >/dev/null

render() {  # name noise scheme login language
  "$APP/Contents/MacOS/render_panel" "$OUT/$1.png" "$2" "$3" "$4" \
    -AppleLanguages "($5)" -AppleLocale "$5"
}

render brown  "Brown"          dark  on  en
render speech "Speech Blocker" dark  off en
render light  "Brown"          light on  en
render ja     "Speech Blocker" dark  on  ja
echo "Wrote panel captures to $OUT"
