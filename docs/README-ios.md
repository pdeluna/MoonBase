# iOS Build Guide

## Requirements (run on macOS)
- Xcode (latest stable)
- CocoaPods
- Fastlane

## One-time
1) App Store Connect: create app and API key.
2) Xcode: set Team and Bundle Identifier on Runner target (Automatic signing).

## Build & Upload
```bash
cd ios
pod install
fastlane beta
```
