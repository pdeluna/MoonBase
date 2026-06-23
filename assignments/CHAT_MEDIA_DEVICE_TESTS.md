# Chat media + foundation device tests

> Branch under test: `phase3-chat-media` (parented on `phase3-foundation`).
> Owner: principal engineer (the unit tests are green; these are the
> on-device checks the DoD requires before Phase 3 Section 0 and Slice A
> can be signed off).

Phase 3 ships two classes of tests:

| Class | Where it runs | What it proves |
| ----- | ------------- | -------------- |
| Unit | `fvm flutter test test/features/` | Logic, serialization, validation, controller wiring. **Already green** (106/106). |
| Manual device | a real Android + iOS device | OS-mediated camera/gallery, file persistence across reinstall, permission denial UX. **The four checks below.** |

The four checks correspond to DoD items **T0.2**, **T0.3** (foundation
device tests), **T1.2**, and **T1.3** (Slice A device tests). They're
listed together because the chat-media flow exercises every foundation
path: picker sheet, both media kinds, both sources, file persistence,
permission denial, app-restart resolution.

---

## Pre-flight (3 min)

1. **Pull the right branch** on a physical device or device emulator:

   ```bash
   fvm flutter pub get
   git fetch origin
   git checkout phase3-chat-media
   ```

2. **Run on Android first**, then iOS. Reinstall (uninstall → install) between checks T0.2 and T1.3 if you want to cleanly verify the relative-key resolver.

3. **Have two test accounts** in two bases so you can cover base isolation later in the same run if you want a stretch goal.

---

## Check 1 — T0.2: pick + persist + reinstall round-trip (Foundation)

**Goal:** prove that `LocalFileMediaStorage` writes under
`documents/media/<baseId>/<uuid>.<ext>` and that `resolveUri` still finds
the file after an app reinstall (i.e., the storage key really is
relative, not an absolute path).

1. Sign in, select any base, open Chat.
2. Tap the new **attach** button (left of the input field) → `MediaPickerSheet` appears with four options.
3. **(a)** Tap **Camera (Photo)** → grant permissions on first prompt → take a photo. The sheet should close and a thumbnail should appear in the staged strip above the input.
4. **(b)** Tap attach again → **Camera (Video)** → record a clip ≤ 30 s → confirm a second thumbnail appears in the strip.
5. **(c)** Tap attach again → **Photo Library** → pick any image → thumbnail appears.
6. **(d)** Tap attach again → **Video Library** → pick any clip ≤ 30 s → thumbnail appears. (The attach button is now disabled because the strip holds 4 items, which is the per-message cap.)
7. Type a caption, hit send. The message should appear in the list with a 2×2 grid of tiles. Tap any tile → `MediaPreview` opens.
8. **Disk audit (optional but recommended):** with the app running, run

   ```bash
   adb shell ls -R /data/user/0/com.example.moonbase_skeleton/files/app_flutter/media
   ```

   (Adjust the package name if needed.) Expected layout:

   ```
   <baseId>/<uuid_1>.jpg
   <baseId>/<uuid_2>.mp4
   <baseId>/<uuid_3>.jpg
   <baseId>/<uuid_4>.mp4
   ```

9. **Reinstall the app** (uninstall then re-run `fvm flutter run`). Sign in again. **Do not re-pick anything.** Open Chat for the same base. The message you sent should still appear, and tapping its tiles should still load via `MediaPreview` (the resolver joins the relative key with the new docs dir).

**Pass criteria:**
- All four picker paths returned a `MediaRef` and rendered.
- Files on disk are under `media/<baseId>/<uuid>.<ext>` (relative-key invariant).
- After reinstall, the previously-sent message still renders. (Phase 3 architectural rule #1 — content-addressable keys, not absolute paths.)

---

## Check 2 — T0.3: permission denial UX (Foundation)

**Goal:** prove that a denied camera or photo-library permission surfaces
as `PermissionDeniedFailure` with the "Open Settings" affordance.

1. Reinstall the app (so the OS re-asks for permission on the first capture).
2. Open Chat, tap attach → **Camera (Photo)**.
3. On the first OS permission prompt, **deny** camera access.
4. Expected: the picker sheet stays up (so the user can pick a different path), and a snackbar appears with:

   > "Permission required. Enable camera or photo access in Settings."

   …with an **"Open Settings"** action.

5. Tap "Open Settings" — the affordance is wired but the deep link is a Phase 4 task. For Phase 3 the visible affordance is what we're verifying. (Don't fail this check if the link is a no-op; that's tracked.)
6. Repeat for the **Photo Library** path (deny photo-library access).

**Pass criteria:**
- No silent failure. No raw `PlatformException`.
- A snackbar with `PermissionDeniedFailure` copy and "Open Settings" appears.

---

## Check 3 — T1.2: chat media end-to-end (Slice A)

**Goal:** prove that chat correctly extends Phase 2's text-only flow to
images + videos, including regressions to text-only.

Run each of the following in order. Between scenarios, observe the staged
strip / send button to confirm enable/disable logic.

1. **Text-only regression.** Send "hello world." The bubble should look exactly like Phase 2 (no media block, no thumbnails).
2. **Image-only.** Tap attach → Photo Library → pick one image → **leave the text field empty** → press send. Bubble shows a single 240×240 tile, no text block under it.
3. **4 images.** Stage four images. Confirm:
   - The attach button is **disabled** after the 4th (tooltip says "Max 4 attachments").
   - Per-item × removes a staged item and re-enables the attach button.
   - Send with caption "look at all these" — bubble shows a 2×2 grid above the text block.
4. **One video ≤ 30 s.** Stage a single video clip → send with a caption → bubble renders a `VideoThumbnail` (greyish placeholder with play icon). Tap → `MediaPreview` plays the clip.
5. **One video > 30 s** (negative path). If the OS picker honors `maxDuration` (iOS does; Android sometimes doesn't), the user is forced to trim; otherwise the validator throws `MediaTooLongFailure` and surfaces "That video is longer than allowed." in the snackbar.
6. **Base switch persistence.** Switch to a different base, then back. The message you sent in step 4 still loads with its tile.

**Pass criteria:**
- All six scenarios work as described; no orphaned snackbars or stuck spinners.
- Removing a staged item × also deletes the on-disk file (verifiable via `adb shell ls -R …/media/<baseId>/`).

---

## Check 4 — T1.3: app-restart re-resolves media (Slice A)

**Goal:** prove that `MediaTile`'s `FutureBuilder<String>` re-resolves
the storage key on a fresh app launch (i.e., the relative-key contract
holds even within a session).

1. Hot-kill the app (swipe away from recents or `adb shell am force-stop ...`).
2. Re-launch via `fvm flutter run` (or by tapping the app icon).
3. Sign in, open the base from Check 3, open Chat.
4. All tiles from the messages you sent should resolve and render. Tap any → `MediaPreview` still works.

**Pass criteria:** every tile renders without a broken-image icon.

---

## When all four checks pass

1. Update [`docs/PHASE3_DOD_ACTION_LIST.md`](../docs/PHASE3_DOD_ACTION_LIST.md) Section 0 status marker:

   > **Status: Complete.** All foundation items shipped on `phase3-foundation`; T0.2 + T0.3 verified on Android + iOS on YYYY-MM-DD.

2. Flag T1.2 + T1.3 in the same way under Slice A.

3. Open a PR for `phase3-chat-media` → `main` (or whatever the integration branch is). The four commits on the branch tell the whole story without you needing a long description.

---

## Known not-blocking items

- **"Open Settings" deep link** in the permission-denied snackbar is a visible affordance with a no-op tap. A `app_settings` plugin integration is a Phase 4 polish task.
- **Legacy widget tests** at `test/legacy/widgets/base_sidebar_test.dart` show 12 pre-existing failures unrelated to Slice A. The README explicitly marks the `test/legacy/` tree as "may be retired."
- **Custom in-app camera surface** (live filters, hold-to-record) is out of scope this phase — Phase 4 will provide an alternative `MediaPicker` implementation behind the same port.
