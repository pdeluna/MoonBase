# Feature Request: Phase 3 Media & Chat Polish

| Field | Value |
| --- | --- |
| **Ticket ID** | MB-P3-POLISH-MEDIA |
| **Maps to DoD** | [`PHASE3_DOD_ACTION_LIST.md`](../docs/PHASE3_DOD_ACTION_LIST.md) Section 0 (T0.3 follow-up) + Slice A UX enhancements |
| **Prerequisite** | Foundation + Slice A merged to `main`; Android device sign-off 2026-06-22 ([`CHAT_MEDIA_DEVICE_TESTS.md`](CHAT_MEDIA_DEVICE_TESTS.md)) |
| **Branch suggestion** | `phase3-media-polish` off `main` |
| **Estimated effort** | P1: ~1–2 h · P2: ~30–60 min · P3: ~4–8 h total |
| **Owner** | *Maintainer or senior contributor* |
| **Reviewer** | *Project maintainer* |
| **Blocks Slice B?** | **P1 only** (Stories reuses `MediaPickerSheet`). P2–P3 do not block junior Stories work. |

> **Scope:** Android-focused implementation and re-test. **iOS device verification is explicitly out of scope** for this ticket (deferred to a separate pass).

---

## Table of Contents

1. [Background & Motivation](#1-background--motivation)
2. [Architectural Guardrails](#2-architectural-guardrails)
3. [Work Items (by Priority)](#3-work-items-by-priority)
4. [Acceptance Criteria](#4-acceptance-criteria)
5. [Self-Review Checklist](#5-self-review-checklist)
6. [Test Plan](#6-test-plan)

---

## 1. Background & Motivation

Android device testing on **2026-06-22** signed off Foundation (T0.2, T0.3 partial) and Slice A (T1.2, T1.3). Core architecture is sound. This ticket captures **one bug** and **three UX enhancements** discovered during manual testing — without expanding Phase 3 scope into Phase 4 (cloud sync, custom camera, etc.).

| ID | Priority | Issue | Device test ref |
| --- | --- | --- | --- |
| **POL-1** | P1 — Bug | Permission-denied snackbar renders behind open `MediaPickerSheet` | T0.3 partial |
| **POL-2** | P2 — Polish | "Open Settings" snackbar action is a no-op | T0.3 partial |
| **POL-3** | P3 — Enhancement | Gallery multi-image pick in one session (cap at 4) | T1.2 observation |
| **POL-4** | P3 — Enhancement | Video first-frame poster in chat bubbles | T1.2 observation |

---

## 2. Architectural Guardrails

These are non-negotiable; polish must not violate them.

1. **`MediaPicker` port stays the boundary.** OS picker details live in `ImagePickerMediaPicker` only. Call sites (`MessageComposer`, future `StoryCaptureScreen`) continue to use `PickAndPersistMedia` / `MediaPickerSheet` — no raw `image_picker` imports in presentation layers.
2. **Dumb tiles.** Do not add Riverpod reads to `MessageBubble` or `MessageComposer` beyond what already exists (`MediaPickerSheet` may read providers; that is sanctioned).
3. **Base-scoped keys.** Any new thumbnail bytes written at pick time use the same `<baseId>/<uuid>.<ext>` pattern via `MediaStorage.putBytes`.
4. **Cap enforcement stays in the use case layer.** Multi-pick appends in the composer, but `SendMessage` still rejects `media.length > 4`.
5. **Minimal dependency additions.** Prefer one small, well-maintained package for Settings deep link (see POL-2). Do not add heavy video-processing libraries for POL-4 — `video_player` first-frame capture is sufficient.

---

## 3. Work Items (by Priority)

### POL-1 (P1) — Permission snackbar visible above picker sheet

**Problem:** When the user denies camera or photo-library access, `_showFailure` in `MediaPickerSheet` calls `ScaffoldMessenger.showSnackBar` while the modal bottom sheet is still open. The sheet occludes the snackbar; the user only sees it after manually dismissing the sheet.

**Files likely touched:**

- `lib/features/media/presentation/widgets/media_picker_sheet.dart`

**Implementation options (pick one; prefer A):**

| Option | Approach |
| --- | --- |
| **A (recommended)** | On `PermissionDeniedFailure` (and optionally all failures): `Navigator.pop(context)` the sheet first, then show snackbar on the **root** scaffold via `ScaffoldMessenger.of(rootNavigatorKey.currentContext!)` or by passing the parent `BuildContext` into `MediaPickerSheet.show`. |
| **B** | Show an inline `Banner` or `AlertDialog` **inside** the sheet instead of a scaffold snackbar. |
| **C** | Pop sheet and return `Left(PermissionDeniedFailure)` to the caller (`MessageComposer`) to show snackbar at screen level. |

**Do not** change failure types or picker domain logic — presentation layering only.

---

### POL-2 (P2) — Wire "Open Settings" deep link

**Problem:** `SnackBarAction.onPressed` is empty (`onPressed: () {}`). Users expect to land on the app's permission page in Android Settings.

**Files likely touched:**

- `lib/features/media/presentation/widgets/media_picker_sheet.dart`
- `pubspec.yaml` (one dependency)
- Optionally extract a tiny `lib/core/platform_settings.dart` helper if you want a testable seam

**Implementation:**

- Add **`app_settings`** *or* **`permission_handler`** (use the smallest surface you need — opening app settings only).
- On "Open Settings" tap: call `openAppSettings()` (or platform equivalent).
- Keep snackbar copy unchanged.

**Out of scope:** re-requesting permission in-app without leaving Settings; iOS-specific permission rationale screens.

---

### POL-3 (P3) — Gallery multi-image pick

**Problem:** Staging 4 images requires opening `MediaPickerSheet` four times. Users expect long-press / multi-select in the gallery (standard Android/iOS gallery UX).

**Files likely touched:**

- `lib/features/media/domain/repositories/media_picker.dart` — add optional `pickMultipleImages(MediaPickRequest request, {int limit})` **or** extend `pickImage` contract with a `allowMultiple` flag (document breaking vs additive choice).
- `lib/features/media/data/datasources/image_picker_media_picker.dart` — delegate to `ImagePicker.pickMultiImage(limit: …)`.
- `lib/features/media/domain/usecases/pick_and_persist_media.dart` — new params or sibling use case returning `List<MediaRef>`.
- `lib/features/media/presentation/widgets/media_picker_sheet.dart` — "Photo Library" path calls multi-pick; respect remaining slots (`maxMedia - staged.length`).
- `lib/features/chat/presentation/widgets/message_composer.dart` — `onStage` may need `onStageMany(List<MediaRef>)` or loop `onStage`.

**Rules:**

- **Gallery images only.** Camera photo, camera video, and video library remain single-pick (OS limitation / UX clarity).
- Stop picking when combined staged + picked count would exceed `MediaConstraints.maxMediaPerMessageDefault` (4).
- Each picked image still runs through size validation + `MediaStorage.putBytes` individually.
- User cancel → no error (same as single pick).

**Tests to add:**

- Unit test: multi-pick returns N refs capped at limit; over-cap bytes still throw `MediaTooLargeFailure`.
- Widget or integration smoke optional.

---

### POL-4 (P3) — Video first-frame poster thumbnail

**Problem:** Sent video messages show `VideoThumbnail` placeholder (grey + play icon) with no actual frame. Device tester requested a default poster.

**Files likely touched:**

- `lib/features/media/data/datasources/image_picker_media_picker.dart` — after video pick, optionally probe first frame via injected `VideoDurationProbe`-style hook or a new `VideoThumbnailGenerator` typedef; write JPEG bytes to `MediaStorage` under a sibling key; set `MediaRef.thumbnailKey`.
- `lib/features/media/presentation/widgets/media_tile.dart` — when `media.type == video` and `thumbnailKey != null`, pass resolved URI into `VideoThumbnail(child: Image(...))`.
- `test/features/media/data/datasources/image_picker_media_picker_test.dart` — mock generator returns a key; assert `MediaRef.thumbnailKey` populated.

**Rules:**

- Thumbnail generation is **best-effort**. Failure to capture a frame must not block the pick — fall back to current placeholder behavior.
- Reuse existing `thumbnailKey` field on `MediaRef`; no schema migration.
- Keep work in the picker/data layer; `MessageBubble` stays unchanged if `MediaTile` handles it.

**Performance note:** First-frame capture adds latency on send. Acceptable for Phase 3; document in PR if p95 pick time regresses noticeably.

---

## 4. Acceptance Criteria

### POL-1 (P1) — Required for ticket close if shipping P1 only

- [ ] Deny camera permission on Android → snackbar is **visible without manually dismissing** the picker sheet first (or sheet auto-dismisses and snackbar appears immediately on Chat screen).
- [ ] Deny photo-library permission → same behavior.
- [ ] Successful pick / user cancel flows unchanged (no double-pop regressions).
- [ ] `fvm flutter analyze` clean; existing `test/features/media/` tests pass.

### POL-2 (P2)

- [ ] Tap "Open Settings" on Android → system Settings opens to this app's permission page (or app details).
- [ ] No-op removed; no crash if Settings cannot open (graceful fallback snackbar optional).

### POL-3 (P3)

- [ ] Photo Library path allows selecting **up to remaining slots** (e.g. 3 if 1 already staged) in **one** gallery session.
- [ ] Staged strip shows all picked thumbnails; send respects 4-cap validation.
- [ ] Camera and video library paths still single-pick.
- [ ] New unit test coverage for multi-pick cap + validation.

### POL-4 (P3)

- [ ] Sent video message in chat shows a **visible poster frame** under the play chrome when first-frame capture succeeds.
- [ ] When capture fails, bubble matches current placeholder (no error surfaced to user).
- [ ] `MediaRef.thumbnailKey` round-trips through `MediaRefCodec` + `MessageModel` (existing message persistence path).

---

## 5. Self-Review Checklist

Before opening PR:

- [ ] PR title follows conventional commits, e.g. `fix(media): show permission snackbar above picker sheet`.
- [ ] One commit per POL item **or** one PR with logically separated commits (P1 first).
- [ ] No new provider reads inside `MessageBubble`.
- [ ] No absolute filesystem paths persisted — only storage keys.
- [ ] `pubspec.yaml` dependency added only for POL-2 (if chosen).
- [ ] Updated [`CHAT_MEDIA_DEVICE_TESTS.md`](CHAT_MEDIA_DEVICE_TESTS.md) Check 2 pass criteria if POL-1/POL-2 change expected UX.
- [ ] Do **not** mark iOS device tests done in this PR.

---

## 6. Test Plan

### Automated

```bash
fvm flutter analyze
fvm flutter test test/features/media/
fvm flutter test test/features/chat/
```

Add tests for any new picker/use-case behavior (POL-3, POL-4).

### Manual (Android only — required before merge)

| After | Re-run |
| --- | --- |
| POL-1 | T0.3 — deny camera + deny gallery; snackbar visible immediately |
| POL-2 | T0.3 — "Open Settings" opens Android app settings |
| POL-3 | T1.2 step 3 — pick 4 images in one gallery session |
| POL-4 | T1.2 step 4 — video bubble shows poster frame; tap still plays in `MediaPreview` |

Regression: T1.3 force-stop → media still renders.

---

## Suggested PR sequencing

| PR | Contains | Merge when |
| --- | --- | --- |
| **PR 1** | POL-1 only | Before junior merges Stories UI that uses `MediaPickerSheet` |
| **PR 2** | POL-2 | Anytime |
| **PR 3** | POL-3 + POL-4 | After Slice B kickoff or in parallel if bandwidth allows |

---

## Explicit non-goals

- iOS device test pass (separate ticket / later).
- Cloud backup or survive-uninstall persistence (Phase 4).
- Multi-select for camera or video library.
- Custom in-app camera, video trimming UI, or compression pipeline changes.
- Stories/Posts feature work (this ticket only touches shared `media` + chat composer integration).
