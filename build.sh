#!/usr/bin/env bash
# Builds leetcode-toggle into a proper macOS .app bundle (menu-bar only)
# as a UNIVERSAL binary (Apple Silicon + Intel), packaged as a .dmg
# with the classic drag-to-Applications layout.
#
# Usage:
#   ./build.sh            # build dist/LeetCodeToggle.app + dist/LeetCodeToggle.dmg
#   ./build.sh run        # build, then run the arm64 binary (dev)
#   ./build.sh install    # build + copy app to /Applications
#   ./build.sh launch     # build + install + launch
#   ./build.sh uninstall  # remove from /Applications
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="LeetCodeToggle"
BUNDLE_ID="com.leetcodetoggle.app"
DIST="dist"
APP="$DIST/$APP_NAME.app"
DMG="$DIST/$APP_NAME.dmg"
MACOS_DIR="$APP/Contents/MacOS"
RES_DIR="$APP/Contents/Resources"
ARM64_BIN=".build/arm64-apple-macosx/release/leetcode-toggle"
X64_BIN=".build/x86_64-apple-macosx/release/leetcode-toggle"
UNIVERSAL_BIN=".build/universal/$APP_NAME"
RES_BUNDLE=".build/arm64-apple-macosx/release/leetcode-toggle_leetcode-toggle.bundle"

# --- Build (both arches -> lipo universal) -------------------------------
# Skip when the universal binary is already newer than every source file
# (avoids re-triggering dsymutil, which can stall under memory pressure).
NEEDS_BUILD=1
if [[ -f "$UNIVERSAL_BIN" && -f "$ARM64_BIN" && -f "$X64_BIN" ]]; then
  NEWEST_SOURCE=$(find Sources Package.swift -type f \( -name '*.swift' -o -name '*.svg' \) -newer "$UNIVERSAL_BIN" 2>/dev/null | head -1)
  [[ -z "$NEWEST_SOURCE" ]] && NEEDS_BUILD=0
fi

if [[ "$NEEDS_BUILD" == 1 ]]; then
  echo "==> Building arm64 (release)…"
  swift build -c release --triple arm64-apple-macosx14.0
  echo "==> Building x86_64 (release)…"
  swift build -c release --triple x86_64-apple-macosx14.0
  echo "==> Creating universal binary…"
  mkdir -p .build/universal
  lipo -create "$ARM64_BIN" "$X64_BIN" -output "$UNIVERSAL_BIN"
else
  echo "==> Universal binary up to date — skipping build."
fi

# --- Assemble the .app ----------------------------------------------------
echo "==> Assembling $APP …"
rm -rf "$APP"
mkdir -p "$MACOS_DIR" "$RES_DIR"

cp "$UNIVERSAL_BIN" "$MACOS_DIR/$APP_NAME"

# SPM places the target's resources in a <target>.bundle next to the binary.
if [[ -d "$RES_BUNDLE" ]]; then
  cp -R "$RES_BUNDLE" "$RES_DIR/"
fi

# Generate the Finder/Dock app icon (.icns) via the binary's CLI mode.
echo "==> Generating app icon…"
ICONSET="$DIST/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
if "$UNIVERSAL_BIN" --app-icon "$ICONSET" && command -v iconutil >/dev/null 2>&1; then
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

# --- Sign -----------------------------------------------------------------
# Ad-hoc signature keeps Gatekeeper from rejecting the app outright on the
# building machine. For public distribution, CI signs with a Developer ID
# and notarizes (see .github/workflows/build.yml) — see README "Distribution".
echo "==> Ad-hoc code signing…"
codesign --force --sign - "$APP" >/dev/null 2>&1 || echo "   (codesign skipped)"

lipo -info "$MACOS_DIR/$APP_NAME" | sed 's/^/   /'

# --- Package as .dmg (classic drag-to-Applications) -----------------------
echo "==> Creating $DMG …"
STAGE="$DIST/dmg-staging"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "LeetCode Toggle" -srcfolder "$STAGE" \
  -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

echo "Done:"
echo "  $APP"
echo "  $DMG"

case "${1:-}" in
  run)
    echo "==> Running dev binary (arm64)…"
    exec "$ARM64_BIN"
    ;;
  install)
    echo "==> Installing to /Applications…"
    pkill -f "$MACOS_DIR/$APP_NAME" 2>/dev/null || true
    pkill -f "/Applications/$APP_NAME.app/Contents/MacOS/$APP_NAME" 2>/dev/null || true
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
    pkill -f "$APP_NAME.app/Contents/MacOS/$APP_NAME" 2>/dev/null || true
    rm -rf "/Applications/$APP_NAME.app"
    echo "Removed."
    ;;
  *)
    echo "Build complete."
    ;;
esac
