#!/usr/bin/env bash
# Builds build/Azimuth for Mac.app from the Swift package, with the Windows build of Azimuth inside.
#   scripts/build-app.sh                 uses ../azimuth-windows.zip
#   AZIMUTH_ZIP=/path/to.zip scripts/build-app.sh
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "build-app.sh must run on macOS." >&2
    exit 1
fi

APP="build/Azimuth for Mac.app"
ZIP="${AZIMUTH_ZIP:-../azimuth-windows.zip}"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/AzimuthMac"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/AzimuthMac"
cp Resources/Info.plist "$APP/Contents/Info.plist"

if [[ -f "$ZIP" ]]; then
    cp "$ZIP" "$APP/Contents/Resources/azimuth-windows.zip"
else
    echo "warning: $ZIP not found; the app will ask for azimuth-windows.zip during setup." >&2
fi

ICONSET="$(mktemp -d)/AppIcon.iconset"
swift scripts/make-icon.swift "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc signature: enough for an app built and run on the same Mac.
codesign --force --deep -s - "$APP"
codesign --verify --deep --strict "$APP"

echo "Built: $APP"
