# Device Debug & Execution Trace Runbook

| Field | Value |
| --- | --- |
| **Audience** | Mentor (Principal) demoing to junior; junior self-serve reference after first walkthrough |
| **Companion docs** | [`CHAT_ARCHITECTURE_DEMO_GUIDE.md`](CHAT_ARCHITECTURE_DEMO_GUIDE.md) (static architecture trace), [`CHAT_MEDIA_DEVICE_TESTS.md`](CHAT_MEDIA_DEVICE_TESTS.md) (manual device checklist) |
| **Platform focus** | Android (primary); iOS notes at bottom |
| **Prerequisite** | USB debugging enabled, `adb` on PATH, FVM + project deps installed |

---

## Table of Contents

1. [Mental model](#1-mental-model)
2. [Session setup](#2-session-setup)
3. [Phase A — Architecture trace (static)](#3-phase-a--architecture-trace-static)
4. [Phase B — Live execution trace (device)](#4-phase-b--live-execution-trace-device)
5. [Phase C — Trace a code change (PR review)](#5-phase-c--trace-a-code-change-pr-review)
6. [Quick reference card](#6-quick-reference-card)
7. [Optional trace logging for new features](#7-optional-trace-logging-for-new-features)
8. [90-minute demo agenda](#8-90-minute-demo-agenda)
9. [iOS notes](#9-ios-notes)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Mental model

Use **three surfaces, one story** when explaining how the app runs on a device:

| Surface | What it shows | Best for |
| --- | --- | --- |
| **IDE debugger** (F5) | Execution stops *inside* a function | “Which line ran, in what order?” |
| **DevTools → Logging** | Clean Dart/Flutter events | “What happened while I tapped?” |
| **Filtered logcat** | Same events in a second terminal | Live device without IDE noise |

**Android Developer Options** (USB debugging, stay awake, etc.) helps you *deploy and debug*. It does **not** reduce log spam — use filtering or DevTools instead.

The MoonBase chat/media stack already emits trace points via `developer.log` (e.g. `ChatController`, `ChatSharedPrefsDataSource`). The workflow is:

1. Set breakpoints on the same code path you expect logs from.
2. Reproduce the user action on device.
3. When execution doesn’t stop, read DevTools / filtered logcat for the last line before silence.

**Events flow down** (Widget → Controller → UseCase → Repository → DataSource → disk).  
**State flows up** (stream / `AsyncValue` → Controller → Widget).

---

## 2. Session setup

Do this **before** the junior sits down (~5 min).

### Terminal 1 — run the app

```powershell
cd "c:\Users\pdelu\App Dev\MoonBase Skeleton\moonbase_skeleton"
fvm flutter devices                    # copy device id
fvm flutter run -d <device-id>
```

Keep this terminal open for the whole session. Note the **DevTools URL** printed at startup.

### Terminal 2 — filtered live log

Flutter-only (cleanest):

```powershell
adb logcat -s flutter
```

Chat + media tags (broader, still readable):

```powershell
adb logcat | Select-String "flutter|ChatController|ChatSharedPrefs|MediaPicker|PickAndPersist|PermissionDenied"
```

### Browser — Flutter DevTools

Use the link from `flutter run`, or launch manually:

```powershell
fvm flutter pub global activate devtools   # once
fvm flutter pub global run devtools
```

Open these tabs before demoing:

- **Logging** — framework events, `debugPrint`, `developer.log`
- **Inspector** — widget tree, which screen is mounted

### IDE — breakpoints (optional but high value)

For the **send text message** trace, set breakpoints in call order (top of stack first):

1. `MessageComposer` — send / attach handler
2. `ChatController.send`
3. `SendMessage` use case
4. `ChatRepositoryImpl.sendMessage`
5. `ChatSharedPrefsDataSource.sendMessage`

For **media attach**, add:

- `MediaPickerSheet._runPick` / `_runGalleryImages`
- `PickAndPersistMedia` or `PickAndPersistMultipleImages`
- `ImagePickerMediaPicker._persistPickedImage` / `_runVideoPick`

Run with **Flutter: Launch (F5)** so the **Debug Console** stays cleaner than a raw `flutter run` terminal.

---

## 3. Phase A — Architecture trace (static)

**Duration:** ~20 min · **Device:** not required

Follow [`CHAT_ARCHITECTURE_DEMO_GUIDE.md`](CHAT_ARCHITECTURE_DEMO_GUIDE.md) **Phase 3**:

1. Draw the layer boxes: **Widget → Controller → UseCase → Repository → DataSource → disk**.
2. Start at **`ChatController`**, not the widget (counter-intuitive but correct).
3. Walk **`load`** then **`send`** using **Go to Definition (F12)** — one hop per layer.
4. Repeat the punchline: *“Stories will have the same boxes with different names.”*

Quiz the junior early: *“Where does the rule that a message can’t be empty live?”*  
Answer: **UseCase** (`SendMessage`), not the widget.

---

## 4. Phase B — Live execution trace (device)

**Duration:** ~25 min · **Requires:** Terminals 1+2 + DevTools + (optional) F5

Pick **one user intent** and observe it on all three surfaces in parallel.

### Demo 1 — Send text message

| Step | Mentor action | Junior observes |
| --- | --- | --- |
| 1 | Tap **Send** on device | DevTools Logging + Terminal 2 |
| 2 | (Optional) F5 with breakpoint on `ChatController.send` | Call stack panel |
| 3 | **Step Over (F10)** through controller → use case → repo | Layer name at each stop |
| 4 | **Continue (F5)** | Log: stream notification |
| 5 | Bubble appears on screen | “State flowed **up** via stream” |

**Expected log sequence (approximate):**

```
ChatController: Sending message…
ChatSharedPrefsDataSource: … persist …
ChatSharedPrefsDataSource: Notifying stream listeners…
ChatController: Received N messages from stream
```

**Diagnostic:** If persist logs appear but the bubble never updates → stream subscription bug (see demo guide §5.1).

### Demo 2 — Attach + send media

Use the same three surfaces. Filter for:

```
MediaPicker
PickAndPersist
ChatController
```

**Expected path:**

```
Tap attach → MediaPickerSheet → use case → ImagePickerMediaPicker → putBytes
→ onStage in MessageComposer → send → ChatController → … → bubble grid
```

Post-polish behaviors to call out:

- **Multi-pick (POL-3):** one gallery session → multiple `putBytes` calls.
- **Video poster (POL-4):** brief pause at pick = first-frame capture.
- **Permission denial (POL-1/2):** sheet dismisses before snackbar; **Open Settings** leaves the app.

### Demo 3 — Permission denial

1. Revoke camera or photo access in Android Settings (or deny on first prompt).
2. Tap attach → **Camera (Photo)** or **Photo Library**.
3. Confirm snackbar is visible **without** manually dismissing the sheet first.
4. Tap **Open Settings** → lands on app info / permissions.

Filter: `PermissionDenied`

---

## 5. Phase C — Trace a code change (PR review)

Use this loop when walking through a merged PR with the junior (e.g. media polish):

1. **Start from device symptom** — “snackbar was hidden” / “couldn’t pick 4 photos”.
2. **Open the PR diff** — find the touched file (`media_picker_sheet.dart`, etc.).
3. **Map to layer** — “Presentation-only; domain unchanged.”
4. **Set one breakpoint** in the new/changed function.
5. **Reproduce on device** — confirm the new branch executes.
6. **Point at the unit test** — `test/features/media/...` — “locks behavior without a phone.”

**Symptom → file → layer → breakpoint/log → unit test.**

---

## 6. Quick reference card

| Goal | Tool |
| --- | --- |
| Clean Flutter-only stream | `adb logcat -s flutter` |
| Chat/media trace | Filter `ChatController\|MediaPicker\|ChatSharedPrefs` |
| Widget tree / what’s mounted | DevTools → **Inspector** |
| Framework + `debugPrint` | DevTools → **Logging** |
| Step through call stack | **F5** → Debug Console |
| Session dropped | `fvm flutter run` or `fvm flutter attach` |
| Teach architecture | [`CHAT_ARCHITECTURE_DEMO_GUIDE.md`](CHAT_ARCHITECTURE_DEMO_GUIDE.md) |
| Device checklist | [`CHAT_MEDIA_DEVICE_TESTS.md`](CHAT_MEDIA_DEVICE_TESTS.md) |

---

## 7. Optional trace logging for new features

When adding Stories (or any new slice), prefer **`developer.log`** with a **stable prefix**:

```dart
import 'dart:developer' as developer;

developer.log(
  'PublishStory: validating base ${baseId.bid}',
  name: 'PublishStory',
);
```

Filter on device:

```powershell
adb logcat | Select-String "PublishStory"
```

Rules:

- Use a **consistent `name:` or message prefix** per feature.
- Prefer `developer.log` over raw `print()` (shows in DevTools Logging).
- Remove noisy debug logs before merge, or keep at meaningful milestones only.

---

## 8. 90-minute demo agenda

| Time | Activity |
| --- | --- |
| 0–15 min | Draw layer diagram; quiz “where does validation live?” |
| 15–50 min | Static trace: `ChatController` → `SendMessage` → repo → prefs (F12) |
| 50–55 min | **Break** — start Terminals 1+2 + DevTools |
| 55–70 min | Live: send text (breakpoints + logs) |
| 70–85 min | Live: attach image (map to `media/` module) |
| 85–90 min | Map chat files → Stories stubs in [`STORIES_FIRST_STEPS.md`](STORIES_FIRST_STEPS.md) |

**Success criterion:** Junior can point at any chat file and name the Stories analog without looking at a cheat sheet.

---

## 9. iOS notes

Same mental model; different filter surface.

**Simulator / device console** (second terminal while `flutter run` is active):

```bash
xcrun simctl spawn booted log stream --predicate 'processImagePath CONTAINS "Runner"' --level debug
```

Or **Xcode → Window → Devices and Simulators → Open Console**, filter for `flutter` or the process name.

DevTools works identically on iOS.

---

## 10. Troubleshooting

### Raw terminal is mostly Android system noise

Normal. `InsetsController`, `AutofillManager`, `WindowOnBackDispatcher`, etc. are not your app.

**Fix:** Don’t read unfiltered terminal output. Use `adb logcat -s flutter`, DevTools Logging, or F5 Debug Console.

### `Lost connection to device`

The debug session ended (USB glitch, crash, `flutter run` stopped, device sleep, cable).

**Fix:**

```powershell
fvm flutter run -d <device-id>
# or, if app still installed:
fvm flutter attach
```

Try another USB cable/port; disable battery optimization for the app on the phone if disconnects are frequent.

### Breakpoint never hits

- Confirm **debug** build (not profile/release).
- Confirm you’re on the code path you think (e.g. gallery multi-pick vs single camera).
- Hot restart after adding breakpoints: **Shift+F5** or `R` in terminal.

### Logs stop mid-flow

The last log line before silence usually identifies the failing layer. Example: persist log without stream notification → subscription not firing.

---

## Related paths (chat/media trace)

| Layer | Example file |
| --- | --- |
| Widget | `lib/features/chat/presentation/widgets/message_composer.dart` |
| Controller | `lib/features/chat/presentation/controllers/chat_controller.dart` |
| Use case | `lib/features/chat/domain/usecases/send_message.dart` |
| Repository | `lib/features/chat/data/repositories/chat_repository_impl.dart` |
| Data source | `lib/features/chat/data/datasources/chat_shared_prefs_data_source.dart` |
| Media pick | `lib/features/media/presentation/widgets/media_picker_sheet.dart` |
| Media persist | `lib/features/media/data/datasources/image_picker_media_picker.dart` |
