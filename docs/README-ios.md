# iOS Firebase device handoff

This is the canonical iOS handoff and physical-device checklist. It separates
facts present on the remote repository from results that exist only on a
developer's machine.

## Current state and hard gates

Audit baseline (**2026-09-17**):

- Remote `origin/main` is `57b1ab9` (merged
  [PR #24](https://github.com/pdeluna/MoonBase/pull/24)). Its checked-in
  records say the Firebase build is stable on Android, but that historical
  device result was not reproduced during this audit.
- iOS Firebase is **not configured** on that revision:
  `DefaultFirebaseOptions.currentPlatform` throws for iOS, `firebase.json`
  lists Android only, and no `GoogleService-Info.plist` is tracked.
- The Runner still uses the placeholder bundle identifier
  `com.example.moonbaseSkeleton`. The Podfile and
  `AppFrameworkInfo.plist` say iOS 15, while the Runner Xcode project says
  iOS 12. These values must be reconciled during the approved iOS pass.
- `.github/workflows/ios.yml` does not parse as YAML, so its failed workflow
  records are not iOS build evidence. TestFlight also requires paid Apple
  Developer Program access; it is not part of the free-signing device check.
- No self-hosted user Mac is connected to the Cursor project. Changes,
  branches, or test results present only on Philip's or his sister's machine
  are therefore unverified until pushed or recorded against a commit SHA.

The sequence is locked:

1. **Android gate (current stop):** on a physical Android device, test exactly
   the intended remote revision. Re-run
   [`CHAT_MEDIA_DEVICE_TESTS.md`](../assignments/CHAT_MEDIA_DEVICE_TESTS.md)
   T1.2 step 4 (a sent video shows a poster and still opens playback), then
   T1.3 (force-stop/relaunch still resolves the media). Record device, Android
   version, commit SHA, and result. Use a full stop and re-run, not hot
   reload/restart, when the Firebase debug harness is involved.
2. **Philip approval:** after that evidence is recorded, Philip explicitly
   approves starting/completing the iOS Firebase pass. Until then, do not
   register the production iOS Firebase app, choose the final bundle ID,
   change signing, configure deployment credentials, or claim iOS complete.
3. **iOS implementation:** generate the iOS Firebase configuration, reconcile
   deployment targets, make the app build, and run non-device checks.
4. **iOS physical-device gate:** run the checklist below. Simulator or CI
   compilation is useful preflight, but does not prove camera, photo-library,
   HEIC, free provisioning, or physical-device behavior.

Minor unrelated bugs are logged for later; they do not silently expand this
pass.

## Approved implementation checklist

After Philip's approval:

1. Choose the final iOS bundle identifier once. Use the same value in the
   Runner target, Firebase iOS app registration, and any later App Store
   record. Do not maintain parallel "temporary" and "real" identifiers.
2. Register that bundle identifier as an iOS app in Firebase project
   `moonbase-aaff7`, then regenerate `lib/firebase_options.dart` and
   `firebase.json` with FlutterFire. Confirm the generated iOS app ID is
   present before changing `DefaultFirebaseOptions.currentPlatform`.
3. Set the Runner, test target, Podfile, and `AppFrameworkInfo.plist` to one
   supported iOS deployment target.
4. Keep Flutter **3.29.2** / Dart **3.7.2** through FVM. Do not use an
   unpinned `stable` SDK on the Mac or in CI.
5. First prove a local, no-codesign build and the non-device suite. Configure
   TestFlight only if Philip separately approves paid-account deployment.

## Philip's sister's Mac: free-signing device test

This procedure uses the Mac as the build host and an attached iPhone/iPad as
the test device. A free Apple ID Personal Team is enough for direct testing;
it does **not** support TestFlight, and the installed development app normally
expires after seven days.

### Prepare the Mac

1. Install and open the latest Xcode supported by macOS. Accept its license and
   allow it to install platform components.
2. Install CocoaPods and FVM, then clone the repository. Follow
   [`DEVELOPMENT_SETUP.md`](DEVELOPMENT_SETUP.md) for the toolchain, but use
   the repository pin rather than `stable`.
3. Check out the approved commit, then run:

   ```bash
   fvm install 3.29.2
   fvm use 3.29.2
   fvm flutter --version
   fvm flutter pub get
   cd ios
   pod install
   open Runner.xcworkspace
   ```

   Open `Runner.xcworkspace`, never `Runner.xcodeproj`, after `pod install`.

### Configure free signing

1. In Xcode, open **Settings → Accounts** and add the Apple ID that will own
   the temporary Personal Team. Philip should enter his own credentials if
   his account is used.
2. Select **Runner → Signing & Capabilities**:
   - enable **Automatically manage signing**;
   - select that **Personal Team**;
   - confirm the bundle identifier is the same approved Firebase identifier.
3. Connect and unlock the iPhone/iPad, tap **Trust** on both devices when
   prompted, and enable **Developer Mode** on the iOS device if requested.
4. Select the physical device as Xcode's run destination and build once. If
   iOS asks to trust the developer profile, follow the on-device prompt under
   **Settings → General → VPN & Device Management**.
5. From the repository root, confirm the device appears and launch the pinned
   build:

   ```bash
   fvm flutter devices
   fvm flutter run -d <ios-device-id>
   ```

### Physical-device acceptance

Record the tested commit SHA, Mac/Xcode version, device/iOS version, network,
and each result:

- cold launch reaches the expected signed-out or signed-in state without an
  unsupported Firebase-options error;
- sign in, list/select a base, send text, and receive it on another signed-in
  device;
- pick a normal library image and an iPhone HEIC image, upload each, and render
  it on both sender and receiver;
- take a camera photo and verify camera/photo permission-denial copy plus
  **Open Settings**;
- force-stop and relaunch; chat and cloud media still resolve;
- test a first-ever sign-in separately from a returning cached session;
- if resilience flags are exercised, fully stop and re-run between modes.

A simulator run is a preflight only. If no physical iOS device is available,
the iOS gate remains open.

## Review/agent model

Use one assessor as gate owner and one implementer between gates. Parallel
agents are useful for read-only branch/history review or independent tests,
but multiple implementation owners create branches and claims that can drift.
At each device gate, the assessor reconciles the tested SHA with the remote
branch before work resumes. This replaces a standing requirement for multiple
implementer agents; add another implementer only for an isolated,
non-overlapping change.

## Later paid deployment

Fastlane/TestFlight is a separate, explicitly approved pass. It requires App
Store Connect setup, paid-program signing assets, repaired CI YAML, protected
secrets, and a successful archive/upload check. A free Personal Team device
run must not be reported as TestFlight readiness.

