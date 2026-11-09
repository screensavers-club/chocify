#!/bin/bash
# Builds "Chocofi HUD.app" and installs it to ~/Applications.
set -euo pipefail
cd "$(dirname "$0")"
APP="build/Chocofi HUD.app"
rm -rf build && mkdir -p "$APP/Contents/MacOS"
swiftc -O -swift-version 5 -o "$APP/Contents/MacOS/ChocofiHUD" Sources/*.swift -framework AppKit -framework IOKit -framework ServiceManagement
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/Chocofi HUD.app"
cp -R "$APP" "$HOME/Applications/"
echo "installed: $HOME/Applications/Chocofi HUD.app"
