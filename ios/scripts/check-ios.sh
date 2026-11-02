#!/bin/bash
# Compile the real iOS target once Xcode and iOS platform support are installed.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode.app/Contents/Developer ]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
if ! xcrun --sdk iphonesimulator --show-sdk-path >/dev/null 2>&1; then
  echo 'Xcode with iOS platform support is required. Install and open Xcode first.' >&2
  echo 'For a custom installation, set DEVELOPER_DIR to its Contents/Developer directory.' >&2
  exit 1
fi
xcodebuild -project WardrobeWeather.xcodeproj -scheme WardrobeWeather \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/ios CODE_SIGNING_ALLOWED=NO build
