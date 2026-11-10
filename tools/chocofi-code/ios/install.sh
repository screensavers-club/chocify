#!/bin/bash
# Builds Chocofi Code for iPad and installs it on a connected, unlocked iPad.
#   ./install.sh               the first available iPad
#   ./install.sh "<device>"    any name/identifier from `xcrun devicectl list devices`
set -euo pipefail
cd "$(dirname "$0")"
DEVICE="${1:-iPad}"
# capture first: awk exiting early would SIGPIPE devicectl and trip pipefail
LIST=$(xcrun devicectl list devices 2>/dev/null || true)
ID=$(echo "$LIST" | grep -F "$DEVICE" | grep -v -e unavailable -e simulated | awk '{for(i=1;i<=NF;i++) if ($i ~ /^[0-9A-F]{8}-/) {print $i; exit}}' || true)
[ -n "$ID" ] || { echo "No connected device matching \"$DEVICE\". Connect it, unlock it, and check Developer Mode is on."; exit 1; }
DETAILS=$(xcrun devicectl device info details --device "$ID" 2>/dev/null || true)
UDID=$(echo "$DETAILS" | awk '/UDID:/{print $NF; exit}')
UDID=${UDID:-$ID}
xcodegen generate >/dev/null
# building for the device itself registers it with the team's provisioning profile
xcodebuild -project ChocofiCode.xcodeproj -scheme ChocofiCode -configuration Release \
  -destination "id=$UDID" -derivedDataPath build -allowProvisioningUpdates -allowProvisioningDeviceRegistration -quiet build
xcrun devicectl device install app --device "$ID" "build/Build/Products/Release-iphoneos/Chocofi Code.app"
xcrun devicectl device process launch --device "$ID" studio.screensavers.chocofi-code || true
