#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
swiftc -D CORE_CHECKS -swift-version 5 Wardrobe/Core/*.swift Tests/CommandLine/XCTestShim.swift Tests/WardrobeCoreTests/WardrobeCoreTests.swift Tests/CommandLine/main.swift -o .build/core-checks
.build/core-checks
swiftc -frontend -parse Wardrobe/Core/*.swift Wardrobe/Services/*.swift Wardrobe/Views/*.swift Wardrobe/WardrobeApp.swift
plutil -lint WardrobeWeather.xcodeproj/project.pbxproj Wardrobe/Info.plist
