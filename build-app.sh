#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "Building verba.io..."
swift build

APP_BUNDLE="build/VerbaIO.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS"

cp .build/debug/VerbaIO "$MACOS/VerbaIO"
cp VerbaIO/Info.plist "$CONTENTS/Info.plist"

echo "App bundle created at: $APP_BUNDLE"
echo ""
echo "To run:"
echo "  open $APP_BUNDLE"
echo ""
echo "On first launch, grant these permissions when prompted:"
echo "  - Microphone access"
echo "  - Speech Recognition"
echo "  - Accessibility (System Settings > Privacy & Security > Accessibility)"
