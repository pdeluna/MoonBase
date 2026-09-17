# MoonBase iOS Personal Team device handoff

This is the canonical repository runbook for one direct physical-device test
on Philip's sister's Mac. It does not cover TestFlight, App Store submission,
paid Apple Developer Program signing, or production distribution.

## Gate status

The repository is coherent up to two external boundaries, but the iOS device
gate is **not closed**:

- Runner uses the intended non-placeholder identifier
  `com.deluna.moonbase` in Debug, Profile, and Release. RunnerTests derives
  `com.deluna.moonbase.RunnerTests`.
- Runner, RunnerTests, CocoaPods, and `AppFrameworkInfo.plist` all target
  iOS 15.0.
- Automatic signing is checked in without a developer team. Selecting a
  Personal Team is a reversible, Mac-local step.
- Camera and photo-library purpose strings describe photos only.
  `NSMicrophoneUsageDescription` and the unused photo-library write
  permission are absent.
- The cloud chat contract remains JPEG images only: at most four attachments,
  caption optional, empty message denied, and video choices hidden/rejected.
- `.github/workflows/ios.yml` is now an unsigned macOS preflight. It does not
  import certificates, download profiles, call Fastlane, or upload to
  TestFlight.
- Firebase CLI authentication was unavailable on the implementation worker
  (`Failed to authenticate, have you run firebase login?`). Therefore no iOS
  app was guessed or created and no fake Firebase values were committed.

The strict repository gate remains blocked until an authorized owner registers
the exact iOS bundle ID in Firebase project `moonbase-aaff7` and commits all
generated surfaces together:

1. `lib/firebase_options.dart` with `TargetPlatform.iOS => ios`;
2. the iOS app mapping in `firebase.json`;
3. `ios/Runner/GoogleService-Info.plist`;
4. the plist's Runner target/resource entry in
   `ios/Runner.xcodeproj/project.pbxproj`.

Run the structural check before that boundary:

```bash
fvm dart run tool/validate_ios_readiness.dart \
  --allow-pending-firebase-registration
```

Run the strict check after generated configuration is committed:

```bash
fvm dart run tool/validate_ios_readiness.dart
```

The pending flag accepts only the fully unconfigured state. A partial Firebase
configuration fails so the four surfaces cannot drift.

## Locked repository decisions

### Identifier and signing

`com.deluna.moonbase` matches the existing Android application ID and is the
single intended iOS identifier. Do not change only Xcode to make free signing
work. If the Personal Team cannot provision this identifier:

1. stop before running the app;
2. record the Xcode error;
3. ask Philip to approve one development identifier;
4. change every Xcode configuration and the validator expectation in one
   commit;
5. register that exact replacement in Firebase and regenerate all four
   configuration surfaces.

Do not silently maintain both a temporary and a final identifier.

The repository deliberately contains `CODE_SIGN_STYLE = Automatic` but no
`DEVELOPMENT_TEAM`. Xcode may add a team ID to the project locally. Before
committing anything from the Mac, inspect the diff and never commit Philip's
sister's Personal Team ID.

### Toolchain and Xcode

Flutter 3.29.2 and Dart 3.7.2 are pinned by `.fvmrc`; all Flutter and Dart
commands must run through FVM. Use an Xcode version that is simultaneously
compatible with:

- Flutter 3.29.2;
- the Mac's macOS version; and
- the attached device's iOS version.

Xcode 16.3 is a known-compatible reference for Flutter 3.29.2 and iOS 15–18.4.
Do not assume a much newer Xcode/device OS is compatible with this pinned
Flutter release. Record the actual versions and stop on a compatibility error
instead of upgrading Flutter during the device pass.

### Images and permissions

The chat attachment sheet exposes only **Camera (Photo)** and
**Photo Library**. Cloud upload always normalizes the selected bytes to JPEG
and writes `bases/{baseId}/media/{uuid}.jpg` with `image/jpeg`.

`image_picker` uses PHPicker on iOS 14+. PHPicker can select photos without a
broad photo-library authorization prompt; that is expected, not a skipped
test. HEIC/HEIF selection and conversion must still be proved on a physical
device because the simulator cannot provide equivalent evidence.

No current UI reaches video capture, and no microphone permission should
appear. Video upload/playback is not an acceptance case.

## One-time Firebase owner step

Do this on a trusted Mac while signed into an account that can modify
`moonbase-aaff7`. Complete it before treating any device result as acceptance.
The generated client files are not server secrets and must be committed.

1. Start from the candidate branch and confirm the intended identity:

   ```bash
   git rev-parse HEAD
   git status --short
   fvm flutter --version
   fvm dart run tool/validate_ios_readiness.dart \
     --allow-pending-firebase-registration
   ```

2. Install the latest Firebase CLI and authenticate interactively:

   ```bash
   npm install --global firebase-tools@latest
   firebase login
   firebase projects:list
   ```

3. Install FlutterFire CLI using the pinned Dart SDK, then configure Android
   and iOS together so the existing Android entry is preserved:

   ```bash
   fvm dart pub global activate flutterfire_cli
   PATH="$PWD/.fvm/flutter_sdk/bin:$PATH" \
     fvm dart pub global run flutterfire_cli:flutterfire configure \
       --yes \
       --project=moonbase-aaff7 \
       --platforms=android,ios \
       --android-package-name=com.deluna.moonbase \
       --ios-bundle-id=com.deluna.moonbase \
       --out=lib/firebase_options.dart \
       --android-out=android/app/google-services.json \
       --ios-out=ios/Runner/GoogleService-Info.plist
   ```

4. Verify that FlutterFire added `GoogleService-Info.plist` to Runner's Copy
   Bundle Resources, then run:

   ```bash
   fvm dart run tool/validate_ios_readiness.dart
   git diff --check
   git status --short
   ```

5. Inspect generated changes. Confirm `PROJECT_ID=moonbase-aaff7`,
   `BUNDLE_ID=com.deluna.moonbase`, and one `GOOGLE_APP_ID` agree across
   Xcode, `firebase_options.dart`, `firebase.json`, and the plist. Commit and
   push them before the physical-device test.

6. In Firebase Console, record App Check enforcement for Authentication,
   Firestore, and Storage. This repository has no App Check provider, so
   affected products must not enforce App Check for this test unless a
   separately approved provider/debug-token setup is committed and evidenced.

## Backend deployment gate

The candidate includes the reviewed Firestore contract that allows text or
one-to-four same-base JPEG paths, including a captionless image, while denying
an empty message. Storage allows authenticated image upload under the base
media path and denies client delete.

Rules tests do not prove deployment. From the exact source SHA to be tested,
an authorized Firebase owner must run and retain the output:

```bash
git rev-parse HEAD
firebase deploy \
  --project=moonbase-aaff7 \
  --only firestore:rules,storage
```

Record that SHA as the deployed-rules SHA. If production rules cannot be
deployed, the live image-only cases remain blocked.

## Philip's sister's Mac procedure

### 1. Prepare and record the host

Install Xcode from Apple and open it once. Accept the license and allow its
platform components to finish. Install Homebrew if needed, then:

```bash
brew install fvm cocoapods
xcodebuild -version
sw_vers -productVersion
pod --version
fvm --version
```

Clone the repository, check out the exact pushed candidate, and do not test a
local-only commit:

```bash
git clone https://github.com/pdeluna/MoonBase.git
cd MoonBase
git fetch origin
git checkout <candidate-branch>
git pull --ff-only origin <candidate-branch>
git rev-parse HEAD
git status --short
```

The status must be clean here. Record the SHA.

### 2. Run the unsigned preflight

```bash
fvm install
fvm flutter --version
fvm dart --version
fvm flutter doctor -v
fvm flutter pub get
fvm dart run tool/validate_ios_readiness.dart
fvm flutter analyze
fvm flutter test --reporter expanded
cd ios
pod install --repo-update
cd ..
fvm flutter build ios --debug --no-codesign
```

Expected toolchain output is Flutter 3.29.2 / Dart 3.7.2, and analysis must
exit with no findings. The three findings recorded by the stacked handoff
were removed so the repaired macOS workflow has a deterministic gate.

Run both rules suites and record their totals:

```bash
cd firestore/tests
npm ci
npm test
cd ../../storage/tests
npm ci
npm test
cd ../..
```

The stacked baseline is 225 Flutter tests, 48 Firestore-rule tests, and
8 Storage-rule tests. Added tests may increase the total; no baseline test may
disappear or fail.

Open the CocoaPods workspace, never the project:

```bash
open ios/Runner.xcworkspace
```

### 3. Configure the Personal Team

1. In **Xcode → Settings → Accounts**, add the Apple Account that will sign
   this direct device build. Xcode must label it **Personal Team**.
2. Select **Runner → Signing & Capabilities**.
3. Keep **Automatically manage signing** enabled.
4. Select the Personal Team and confirm the bundle identifier remains exactly
   `com.deluna.moonbase`.
5. If provisioning fails, stop and follow the identifier decision process
   above. Never change Xcode alone.
6. Connect and unlock the iPhone/iPad. Trust the Mac and device prompts and
   enable **Developer Mode** if requested.
7. Select the physical device as the run destination and build once in Xcode.
   If iOS requests developer trust, follow the device's
   **Settings → General → VPN & Device Management** prompt.

After Xcode saves signing, run:

```bash
git status --short
git diff -- ios/Runner.xcodeproj/project.pbxproj
fvm flutter devices
fvm flutter run -d <ios-device-id>
```

Only a documented automatic-signing/Personal-Team delta may be uncommitted.
Any source, Firebase, identifier, permission, or deployment-target delta must
be committed, pushed, and rebuilt before testing. A free provisioning profile
expires after seven days; this proves direct testing only.

### 4. Run physical-device acceptance

Use the documented home dual-stack Wi-Fi and a second signed-in client in the
same base. Record each result separately:

1. Fresh install/cold launch reaches the signed-out or signed-in shell without
   an unsupported Firebase-options error. Complete a first-ever sign-in.
2. Send and receive a text-only message. Confirm an empty message cannot send.
3. Open attachments. Only **Camera (Photo)** and **Photo Library** appear.
   No video choice or microphone prompt appears.
4. From a reset app privacy state, deny the camera prompt. The picker dismisses,
   the permission snackbar and **Open Settings** appear, Settings opens the
   MoonBase page, and granting camera access then retrying succeeds.
5. Exercise Photo Library separately. If iOS shows authorization, deny it and
   verify the same recovery. If PHPicker shows scoped selection without broad
   authorization, record that expected path and prove selection succeeds.
6. Send a normal library image with no caption and render it on both devices.
7. Confirm a source photo is HEIC/HEIF, send it, and verify the resulting
   cloud object/message path is JPEG and renders on both devices.
8. Take and send a camera photo; verify it on both devices.
9. Send four images in one message. Confirm a fifth attachment cannot be
   staged.
10. Send an image from the second client back to iOS and verify iOS resolves
    it; sender-local rendering alone is insufficient.
11. Force-quit MoonBase from the app switcher. Relaunch from its icon without
    rebuilding, reinstalling, hot reload, or hot restart. The returning session,
    base/chat, sent images, remote image, and HEIC-origin image must resolve.
12. Record App Check warnings. Enforcement cannot be silently waived.

If a debug-harness mode is exercised, fully stop and rerun the app for that
mode. Hot restart/reload wedges the harness gRPC channel and is not valid
evidence.

## Evidence record

Keep one record containing:

- candidate branch and exact pushed app SHA;
- clean pre-signing status and the post-signing diff;
- deployed-rules SHA and deploy output;
- bundle ID, Firebase iOS app ID, and Firebase project;
- App Check enforcement state;
- Mac model, macOS, Xcode, CocoaPods, FVM, Flutter, and Dart versions;
- physical device model/iOS and Personal Team account type;
- second-client identity and device type;
- home dual-stack network confirmation;
- command outputs and pass/fail evidence for every acceptance row;
- first-install and returning-session results separately;
- all failures, warnings, screenshots, and logs.

Linux/macOS simulator or unsigned CI evidence cannot close signing,
permissions, HEIC conversion, process-death recovery, two-device realtime, or
dual-stack physical-device gates.

## Known Windows worker blocker

Project evidence
`media/windows-worker-node-abi-error.png` shows the attempted Windows Cursor
worker failed before MoonBase validation: Cursor's native
`better_sqlite3.node` was compiled for `NODE_MODULE_VERSION 137`, while the
worker's Node runtime required `127`. This is a Cursor worker native ABI
mismatch, not a MoonBase Firebase/rules-test failure and not evidence about the
Mac's Node installation. It explains why that worker could not supply
additional device evidence; it does not waive any iOS gate.

## Deferred paid deployment

`ios/fastlane/Fastfile` is legacy, inert configuration and is not called by
the current workflow. Do not add App Store Connect keys, distribution
certificates, App Store profiles, TestFlight upload, or production signing to
this pass. Those require separate paid-program approval and validation.

