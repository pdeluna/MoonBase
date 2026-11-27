# Flutter 3.38 upgrade

Upgrade-only record for pinning MoonBase to Flutter **3.38.10** / Dart **3.10.9**. No feature work. FlutterFire versions were not moved. iOS was not built on this pass (Windows only).

**Commits:** `0ef8963` (FVM pin and lockfile), `3017fd4` (Android toolchain). Branch `chore/flutter-3.38-upgrade`.

---

## Provenance

Measured on Windows, 2026-11-27, from `origin/main` at `0fa6549`. Baseline on Flutter 3.29.2 / Dart 3.7.2: `fvm flutter analyze` exit 0, no issues; `fvm flutter test` exit 0, 477 passed. After the toolchain change, on 3.38.10: the same analyze result, the same 477 tests, and both `fvm flutter build apk --debug` and `--release` exit 0.

`flutter.compileSdkVersion` in the 3.38.10 SDK is **36**. `flutter.targetSdkVersion` is **36**. `flutter.minSdkVersion` is **24**. `flutter.ndkVersion` is **28.2.13676358**.

---

## Versions

| Item | Before (3.29.2) | After (3.38.10) |
| --- | --- | --- |
| Flutter / Dart | 3.29.2 / 3.7.2 | 3.38.10 / 3.10.9 |
| Gradle | 8.12 | 8.14 |
| Android Gradle Plugin | 8.9.1 | 8.11.1 |
| Kotlin Gradle Plugin | 2.1.0 | 2.2.20 |
| Java bytecode (`source` / `target` / `jvmTarget`) | 11 | 17 |
| JDK that ran Gradle | Android Studio JBR 21.0.5 | Same JBR, now set with `fvm flutter config --jdk-dir` |
| `compileSdk` | `flutter.compileSdkVersion` (35) | `flutter.compileSdkVersion` (36) |
| `targetSdk` | `flutter.targetSdkVersion` (35) | **35**, pinned |
| `minSdk` | 23 | `flutter.minSdkVersion` (24) |
| NDK | pinned `27.0.12077973` | `flutter.ndkVersion` (`28.2.13676358` on this SDK) |
| iOS deployment target | 15.0 | 15.0 (unchanged) |

Both built APKs report `compileSdkVersion='36'`, `sdkVersion:'24'`, `targetSdkVersion:'35'`.

---

## Files

| File | Why |
| --- | --- |
| `.fvmrc` | Names the exact SDK `3.38.10`. |
| `pubspec.lock` | Solver moved seven transitive packages to the versions Flutter 3.38.10's `flutter` and `flutter_test` require. Direct app constraints were not edited. The lockfile Dart bound became `>=3.8.0-0 <4.0.0` because `flutter_test` in this SDK requires `sdk: ^3.8.0-0`. |
| `android/gradle/wrapper/gradle-wrapper.properties` | 3.38's tested Gradle is 8.14. AGP 8.11.1 needs Gradle 8.13 or newer. |
| `android/settings.gradle.kts` | AGP 8.11.1 and Kotlin 2.2.20 are the set Flutter 3.38 tested. 2.2.20 is the newest Kotlin that release calls supported, so this pass did not go higher. Google Services stays 4.4.4. |
| `android/app/build.gradle.kts` | Java 17 bytecode, NDK via `flutter.ndkVersion`, `minSdk` left as the migrator wrote it, `targetSdk` pinned to 35. `compileSdk` still follows Flutter. |

---

## Packages that moved

FlutterFire did not move: `firebase_core` 4.13.0, `firebase_auth` 6.5.7, `cloud_firestore` 6.8.0, `firebase_storage` 13.4.6.

| Package | Was | Now | Why |
| --- | --- | --- | --- |
| `fake_async` | 1.3.2 | 1.3.3 | `flutter_test` pins 1.3.3. The app's `^1.3.1` dev constraint allows it. |
| `test_api` | 0.7.4 | 0.7.7 | `flutter_test` pin. |
| `vector_math` | 2.1.4 | 2.2.0 | `flutter` and `flutter_test` pin. |
| `meta` | 1.16.0 | 1.17.0 | `flutter` and `flutter_test` pin. |
| `leak_tracker_flutter_testing` | 3.0.9 | 3.0.10 | `flutter_test` pin. |
| `leak_tracker` | 10.0.8 | 11.0.2 | 3.0.10 requires `>=11.0.1 <12.0.0`. |
| `leak_tracker_testing` | 3.0.1 | 3.0.2 | 3.0.10 allows `>=3.0.1 <4.0.0`; the solver took 3.0.2. |

---

## Decisions

**NDK.** Option B: `ndkVersion = flutter.ndkVersion`. On 3.38.10 that is r28 `28.2.13676358`, which the debug build installed. A later Flutter that changes `flutter.ndkVersion` will change this app's NDK with it.

**minSdk 24 was forced, not chosen.** `android/app/build.gradle.kts` still said `minSdk = 23` when the debug build started. Flutter printed `Upgrading build.gradle.kts` and `MinSdkVersionMigration` (3.38.10) rewrote a literal `minSdk` of 16–23 to `minSdk = flutter.minSdkVersion` before Gradle ran. There was no Gradle error about 23. The [3.38 announcement](https://flutter.dev/blog/whats-new-in-flutter-3-38) lists `flutter.minSdkVersion` (API 24) or higher as the configured minimum. Putting a literal 23 back will be rewritten on the next `flutter build`.

**targetSdk 35 is pinned on purpose.** `flutter.targetSdkVersion` on this SDK is 36. The app pins `targetSdk = 35` so runtime behavior does not change in this upgrade. Moving to 36 is a separate change. `compileSdk` stays `flutter.compileSdkVersion` (36).

**Gradle JDK.** Gradle 8.14 ran on Android Studio's bundled JBR, OpenJDK **21.0.5**, at `C:\Program Files\Android\Android Studio\jbr`. That path is set with `fvm flutter config --jdk-dir`. The setting is machine-local and is not in the repo. Each dev machine needs its own JDK 17 or newer pointed at the same way. Bytecode target remains 17. No Temurin JDK was installed.

**Swift Package Manager stays off.** 3.38.10 makes `enable-swift-package-manager` available on stable and leaves it off unless set. This machine's flag is unset. The repo has no `Package.swift`. `ios/Podfile` still uses CocoaPods (`use_frameworks!`, `flutter_install_all_ios_pods`).

**iOS deployment stays 15.0.** `ios/Podfile` (`platform :ios, '15.0'` and the pod `IPHONEOS_DEPLOYMENT_TARGET`), `ios/Runner.xcodeproj/project.pbxproj`, and `ios/Flutter/AppFrameworkInfo.plist` are all 15.0. Flutter 3.38.10's new-app template uses 13.0. 15.0 is above that floor and matches the existing Firebase baseline.

---

## Verification

**Android.** Two-device smoke check passed on emulators: sign-in, messaging, and sync.

**Deferred device checks.** The physical two-device check, and the known bad dual-stack Wi-Fi check, wait for the voice-calls A1 device test.

**iOS.** Not yet built. The Mac-day checklist below is pending. Xcode 14 is the minimum; Xcode 15 is recommended.

**Follow-ups.** `kotlinOptions` → `compilerOptions`. `targetSdk` 36 is a separate change. UIScene before Flutter 3.41 or Xcode 27.

---

## Deferred

| Item | Revisit when |
| --- | --- |
| iOS UIScene lifecycle | A build uses Xcode 27 (the SDK that fails to launch UIKit apps without UIScene), or Flutter moves to 3.41 or later, where UIScene migration becomes the default. On 3.38 the flag `enable-uiscene-migration` exists and is off. `ios/Runner/AppDelegate.swift` is still the stock `FlutterAppDelegate` plus plugin registration. Do not enable the flag on this pin. |
| `kotlinOptions` → `compilerOptions` | The Android build rejects `kotlinOptions`, or the next intentional Android Gradle edit. Debug and release both compiled with `kotlinOptions { jvmTarget = "17" }` on Kotlin 2.2.20. |
| `targetSdk` 36 | A separate change, after this upgrade is accepted. |
| `docs/README-ios.md` toolchain section and `.cursor/rules/moonbase-project-context.mdc` | They still name Flutter 3.29.2 / Dart 3.7.2. Update them when this pin is the accepted SDK, so those pages do not disagree with `.fvmrc`. |
| Physical two-device check and the known bad dual-stack Wi-Fi check | Voice-calls A1 device test. Emulator sign-in, messaging, and sync already passed. |
| Physical iPhone build | Mac day. Checklist below. |

---

## Mac-day checklist

Flutter 3.38.10's tool (`packages/flutter_tools/lib/src/macos/xcode.dart`) requires **Xcode 14** and recommends **Xcode 15** (doctor warns below 15, errors below 14). Flutter does not publish a separate macOS floor. Apple's [Xcode system requirements](https://developer.apple.com/xcode/system-requirements/) say Xcode 14.0.x runs on macOS Monterey **12.5** or later, and Xcode 15.0.x requires macOS Ventura **13.5**. The 3.38 announcement also says the release supports Xcode 26 / iOS 26 / macOS 26; that is the top of the range. CocoaPods minimum in this SDK is **1.10.0**, recommended **1.16.2**.

On the Mac, from this branch:

1. `git pull` the branch (do not merge to `main` here).
2. `fvm install`, then `fvm flutter --version` and confirm **3.38.10** / Dart **3.10.9**.
3. `fvm flutter pub get`.
4. `cd ios` and `pod install`. Leave Swift Package Manager off. Do not set `enable-uiscene-migration`.
5. Build to a physical iPhone (`fvm flutter run` or an Xcode Run). Confirm the deployment target is still 15.0.
6. Firebase sign-in against project `moonbase-aaff7`.
7. Send a message from the iPhone and receive it on Android, then the other way around.

`docs/README-ios.md` is still the signing and permission runbook. Its toolchain paragraph still says Flutter 3.29.2; use `.fvmrc` and this file for the SDK pin.
