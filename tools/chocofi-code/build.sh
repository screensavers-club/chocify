#!/bin/bash
# Builds "Chocofi Code.app" and installs it to ~/Applications.
set -euo pipefail
cd "$(dirname "$0")"
APP="build/Chocofi Code.app"
rm -rf build && mkdir -p "$APP/Contents/MacOS"
swiftc -O -swift-version 5 -o "$APP/Contents/MacOS/ChocofiCode" Sources/*.swift -framework AppKit
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/Chocofi Code.app"
cp -R "$APP" "$HOME/Applications/"
echo "installed: $HOME/Applications/Chocofi Code.app"
