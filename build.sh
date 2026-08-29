#!/usr/bin/env bash
# Builds leetcode-toggle into a proper macOS .app bundle (menu-bar only)
# and optionally installs/launches it.
#
# Usage:
#   ./build.sh            # build dist/LeetCodeToggle.app
#   ./build.sh run        # build, then run the raw binary (dev)
#   ./build.sh install    # build + copy to /Applications
#   ./build.sh launch     # build + install + launch
#   ./build.sh uninstall  # remove from /Applications
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="LeetCodeToggle"
BUNDLE_ID="com.leetcodetoggle.app"
DIST="dist"
APP="$DIST/$APP_NAME.app"
MACOS_DIR="$APP/Contents/MacOS"
RES_DIR="$APP/Contents/Resources"
BIN=".build/release/leetcode-toggle"

# Skip the build if the release binary is already newer than every source
# file (avoids re-triggering dsymutil, which can stall under memory pressure).
NEEDS_BUILD=1
if [[ -f "$BIN" ]]; then
  NEWEST_SOURCE=$(find Sources Package.swift -type f \( -name '*.swift' -o -name '*.svg' \) -newer "$BIN" 2>/dev/null | head -1)
  [[ -z "$NEWEST_SOURCE" ]] && NEEDS_BUILD=0
fi
if [[ "$NEEDS_BUILD" == 1 ]]; then
  echo "==> Building (release)…"
  swift build -c release
else
  echo "==> Release binary up to date — skipping build."
fi

echo "==> Assembling $APP …"
rm -rf "$APP"
mkdir -p "$MACOS_DIR" "$RES_DIR"

cp "$BIN" "$MACOS_DIR/$APP_NAME"

# SPM places the target's resources in a <target>.bundle next to the binary.
RESOURCE_BUNDLE=".build/release/leetcode-toggle_leetcode-toggle.bundle"
if [[ -d "$RESOURCE_BUNDLE" ]]; then
  cp -R "$RESOURCE_BUNDLE" "$RES_DIR/"
fi

# Generate the Finder/Dock app icon (.icns) via the binary's CLI mode.
echo "==> Generating app icon…"
ICONSET="$DIST/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
if "$BIN" --app-icon "$ICONSET" && command -v iconutil >/dev/null 2>&1; then
  iconutil -c icns "$ICONSET" -o "$RES_DIR/AppIcon.icns"
  rm -rf "$ICONSET"
else
  echo "   (app icon skipped)"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>            <string>LeetCode Toggle</string>
  <key>CFBundleDisplayName</key>     <string>LeetCode Toggle</string>
  <key>CFBundleExecutable</key>      <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>        <string>AppIcon</string>
  <key>CFBundleIdentifier</key>      <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key> <string>6.0</string>
  <key>CFBundlePackageType</key>     <string>APPL</string>
  <key>CFBundleShortVersionString</key> <string>1.0.0</string>
  <key>CFBundleVersion</key>         <string>1</string>
  <key>LSMinimumSystemVersion</key>  <string>14.0</string>
  <key>LSUIElement</key>             <true/>
  <key>NSHighResolutionCapable</key> <true/>
  <key>NSAppTransportSecurity</key>
  <dict><key>NSAllowsArbitraryLoads</key><true/></dict>
</dict>
</plist>
PLIST

echo "==> Ad-hoc code signing…"
codesign --force --sign - "$APP" >/dev/null 2>&1 || echo "   (codesign skipped)"

echo "Done: $APP"

case "${1:-}" in
  run)
    echo "==> Running dev binary…"
    exec "$BIN"
    ;;
  install)
    echo "==> Installing to /Applications…"
    pkill -f "$MACOS_DIR/$APP_NAME" 2>/dev/null || true
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP" /Applications/
    codesign --force --sign - "/Applications/$APP_NAME.app" >/dev/null 2>&1 || true
    echo "Installed: /Applications/$APP_NAME.app"
    ;;
  launch)
    "$0" install
    echo "==> Launching…"
    open "/Applications/$APP_NAME.app"
    ;;
  uninstall)
    echo "==> Removing /Applications/$APP_NAME.app …"
    pkill -f "LeetCodeToggle.app/Contents/MacOS/$APP_NAME" 2>/dev/null || true
    rm -rf "/Applications/$APP_NAME.app"
    echo "Removed."
    ;;
  *)
    echo "Build complete."
    ;;
esac
