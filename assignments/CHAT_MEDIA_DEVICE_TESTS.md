# Chat media + foundation device tests

> **Branch under test:** `main` (Foundation + Slice A merged 2026-06-22).
> **Device sign-off:** Android physical device, **2026-06-22** — principal engineer.
> **Follow-up UX fixes:** [`PHASE3_MEDIA_POLISH_TICKET.md`](PHASE3_MEDIA_POLISH_TICKET.md).

Phase 3 ships two classes of tests:

| Class | Where it runs | What it proves |
| ----- | ------------- | -------------- |
| Unit | `fvm flutter test test/features/` | Logic, serialization, validation, controller wiring. **Green** (106/106 on `main`). |
| Manual device | Physical Android (iOS deferred) | OS-mediated camera/gallery, in-install persistence, permission denial UX. **Four checks below.** |

The four checks correspond to DoD items **T0.2**, **T0.3** (foundation
device tests), **T1.2**, and **T1.3** (Slice A device tests).

---

## Device sign-off record (Android — 2026-06-22)

| Check | Result | Notes |
| ----- | ------ | ----- |
| **T0.2** | **Pass** | All four picker paths send; media survives hot restart and force-stop within the same install. |
| **T0.3** | **Partial pass** | Snackbar appears with correct copy + "Open Settings" action, but renders **behind** the open picker sheet until dismissed. "Open Settings" tap is a no-op (tracked in polish ticket). |
| **T1.2** | **Pass** | Text-only, image-only, 4-image grid, video, base-switch isolation all verified. |
| **T1.3** | **Pass** | Force-stop / relaunch preserves sent media tiles. |

### Local-only persistence (important)

**Full app uninstall wipes all MoonBase data** — users, bases, chat history,
and media files. This is **expected** in Phase 3:

- Chat/bases/users → `SharedPreferences` (removed on uninstall)
- Media blobs → app documents directory (removed on uninstall)

The meaningful persistence tests are **hot restart**, **force-stop**, and
**relaunch within the same install** (T1.3). Do **not** use uninstall to
verify chat history survival until Phase 4 cloud sync ships.

Relative storage keys (`media/<baseId>/<uuid>.<ext>`) matter so that media
**re-resolves correctly after process death** and will support cloud/local
hybrid storage later — not so that data survives uninstall without a server.

---

## Pre-flight (3 min)

1. **Pull latest `main`:**

   ```bash
   git checkout main
   git pull origin main
   fvm flutter pub get
   fvm flutter run -d <android-device-id>
   ```

2. **Platform:** Android verified; iOS run deferred (not blocking Slice B).

3. **Optional:** two bases on one account for base-switch step in Check 3.

---

## Check 1 — T0.2: pick + persist + in-install round-trip (Foundation)

**Goal:** prove that `LocalFileMediaStorage` writes under
`documents/media/<baseId>/<uuid>.<ext>` and that `resolveUri` still finds
the file after **hot restart or force-stop + relaunch** (relative keys, not
absolute paths).

1. Sign in, select any base, open Chat.
2. Tap the **attach** button (left of the input field) → `MediaPickerSheet` appears with four options.
3. **(a)** Tap **Camera (Photo)** → grant permissions on first prompt → take a photo. The sheet should close and a thumbnail should appear in the staged strip above the input.
4. **(b)** Tap attach again → **Camera (Video)** → record a clip ≤ 30 s → confirm a second thumbnail appears in the strip.
5. **(c)** Tap attach again → **Photo Library** → pick any image → thumbnail appears.
6. **(d)** Tap attach again → **Video Library** → pick any clip ≤ 30 s → thumbnail appears. (The attach button is now disabled because the strip holds 4 items, which is the per-message cap.)
7. Type a caption, hit send. The message should appear in the list with a 2×2 grid of tiles. Tap any tile → `MediaPreview` opens.
8. **Disk audit (optional but recommended):** with the app running, run

   ```bash
   adb shell ls -R /data/user/0/com.example.moonbase_skeleton/files/app_flutter/media
   ```

   Expected layout:

   ```
   <baseId>/<uuid_1>.jpg
   <baseId>/<uuid_2>.mp4
   <baseId>/<uuid_3>.jpg
   <baseId>/<uuid_4>.mp4
   ```

9. **In-install persistence:** hot restart (`R` in `flutter run`) or force-stop + relaunch. Open Chat for the same base. The message you sent should still appear; tapping tiles should still open `MediaPreview`.

   > **Not a pass/fail criterion:** full uninstall. Uninstall removes all app data by design in Phase 3 local-only.

**Pass criteria:**
- All four picker paths returned a `MediaRef` and rendered.
- Files on disk are under `media/<baseId>/<uuid>.<ext>` (relative-key invariant).
- After hot restart or force-stop + relaunch, previously-sent media still renders.

---

## Check 2 — T0.3: permission denial UX (Foundation)

**Goal:** prove that a denied camera or photo-library permission surfaces
as `PermissionDeniedFailure` with the "Open Settings" affordance.

1. Reinstall the app (so the OS re-asks for permission on first capture), or reset app permissions in Android Settings.
2. Open Chat, tap attach → **Camera (Photo)**.
3. On the first OS permission prompt, **deny** camera access.
4. Expected: snackbar with:

   > "Permission required. Enable camera or photo access in Settings."

   …and an **"Open Settings"** action.

   **Known gap (polish ticket):** snackbar may appear **behind** the picker sheet until you dismiss the sheet. After polish, it should be visible immediately.

5. Tap "Open Settings" — currently a no-op; polish ticket wires the deep link.
6. Repeat for the **Photo Library** path (deny photo-library access).

**Pass criteria:**
- No silent failure. No raw `PlatformException`.
- Snackbar with `PermissionDeniedFailure` copy and "Open Settings" appears (visibility layering fix tracked separately).

---

## Check 3 — T1.2: chat media end-to-end (Slice A)

**Goal:** prove that chat correctly extends Phase 2's text-only flow to
images + videos, including regressions to text-only.

Run each of the following in order:

1. **Text-only regression.** Send "hello world." The bubble should look exactly like Phase 2 (no media block, no thumbnails).
2. **Image-only.** Tap attach → Photo Library → pick one image → **leave the text field empty** → press send. Bubble shows a single 240×240 tile, no text block under it.
3. **4 images.** Stage four images. Confirm attach disabled at 4; × removes and re-enables attach; send with caption → 2×2 grid above text.
4. **One video ≤ 30 s.** Stage a single video → send with caption → bubble shows `VideoThumbnail` (placeholder + play icon). Tap → `MediaPreview` plays.
5. **One video > 30 s** (negative path). Trim forced or snackbar "That video is longer than allowed."
6. **Base switch persistence.** Switch base away and back; media from step 4 still loads.

**Pass criteria:**
- All six scenarios work as described.
- Removing a staged item × deletes the on-disk file (optional `adb` audit).

---

## Check 4 — T1.3: app-restart re-resolves media (Slice A)

**Goal:** prove that `MediaTile` re-resolves the storage key on a fresh process launch.

1. Force-stop the app (`adb shell am force-stop com.example.moonbase_skeleton` or swipe from recents).
2. Relaunch via `fvm flutter run` or the app icon.
3. Sign in, open the base from Check 3, open Chat.
4. All tiles from previously sent messages should render. Tap any → `MediaPreview` works.

**Pass criteria:** every tile renders without a broken-image icon.

---

## When all four checks pass

1. Update [`docs/PHASE3_DOD_ACTION_LIST.md`](../docs/PHASE3_DOD_ACTION_LIST.md) Section 0 and Slice A status markers (done for Android 2026-06-22).
2. Log any partial passes or enhancement requests in [`PHASE3_MEDIA_POLISH_TICKET.md`](PHASE3_MEDIA_POLISH_TICKET.md).
3. Junior contributors: `git pull origin main` before starting Slice B.

---

## Known not-blocking items

Tracked in [`PHASE3_MEDIA_POLISH_TICKET.md`](PHASE3_MEDIA_POLISH_TICKET.md):

- Permission snackbar hidden behind modal picker sheet (P1).
- "Open Settings" deep link no-op (P2).
- Gallery multi-image pick in one session (P3).
- Video first-frame poster thumbnail in chat bubbles (P3).

Other:

- **Legacy widget tests** at `test/legacy/widgets/base_sidebar_test.dart` — 12 pre-existing failures; unrelated to Slice A.
- **Custom in-app camera surface** — out of scope; Phase 4 alternative `MediaPicker` impl.
