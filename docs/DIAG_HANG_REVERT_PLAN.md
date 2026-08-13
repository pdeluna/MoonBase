# DIAG_HANG revert plan

**Status:** Executed **2026-08-13** on `feature/firebase-integration`. Do not re-run.

**What survived**

1. `includeMetadataChanges: true` on the chat message stream (R5 / inventory C).
2. The debug harness: `lib/core/debug/firebase_debug_harness.dart`, the on-screen banner, README § "Debug network harness".
3. `android/app/src/debug/AndroidManifest.xml` and `network_security_config.xml` (debug-only cleartext exemption for `192.0.2.1`).

**Measurements** now live in [`RESILIENCE_DECISIONS.md`](RESILIENCE_DECISIONS.md) (they cannot be regenerated without equivalent logging). **Naming convention** for the next `DIAG_<TOPIC>` session is copied there so this file can be deleted later without losing it.

---

Historical procedure below. **Do not `git revert 0ddc373`.** That commit mixed permanent harness support with throwaway prints; a wholesale revert silently breaks Storage blackhole. The strip is done; do not re-run.

| Item | Value |
|------|--------|
| Branch at write-up | `feature/firebase-integration` |
| Throwaway+permanent mixed commit | `0ddc373` (`debug(diag): instrument auth-gate, chat snapshots, and Storage blackhole cleartext`) |
| Earlier throwaway commit | `19a1e69` (`feat(media): cloud upload storage and send-flow wiring (pass 1-2)` — DIAG_HANG added alongside real media work; **do not revert the commit**) |
| Permanent harness commit | `d192b26` (`feat(debug): add Firebase offline/blackhole network harness`) |
| Removal method | Surgical edit. Strip DIAG_HANG prints and their scaffolding. Leave inventory B and C. Rewrite the Android comments that currently say "remove with DIAG_HANG". |

---

## Do not `git revert 0ddc373`

`0ddc373` bundled two different categories:

1. Throwaway `DIAG_HANG` prints (auth-gate, splash, router, `getCurrentUser`, chat snapshot emissions).
2. The debug-only cleartext exemption (`android/app/src/debug/AndroidManifest.xml` + `android/app/src/debug/res/xml/network_security_config.xml`).

The second category is **permanent harness support**, same class as `lib/core/debug/firebase_debug_harness.dart` from `d192b26`. `FirebaseStorage.useStorageEmulator` forces `http://`. Without the exemption, Android's default cleartext policy rejects `192.0.2.1` instantly with `IOException: Cleartext HTTP traffic to 192.0.2.1 not permitted`. Blackhole then looks armed (banner, define) but Storage fails locally instead of hanging — a useless fixture.

`19a1e69` is also not revertible as a unit: it is the real media upload-then-create work, with DIAG_HANG prints mixed in.

**Correct approach:** edit the files in inventory A. Restore the control-flow shapes given below. Leave inventory B files in place (rewrite their TEMP comments). Keep `includeMetadataChanges: true` (inventory C). Then run the verification checklist, especially the blackhole image-hang check.

---

## Inventory A — Remove

Every DIAG_HANG print from this investigation, across both commits. One pass.

Grep to drive the pass: `rg DIAG_HANG lib/` must be empty when you are done. (`docs/` will still match this file; that is expected.)

### `0ddc373` set

| File | What it logs | Commit | Removal notes |
|------|--------------|--------|----------------|
| `lib/main.dart` | `DIAG_HANG appStart currentUser uid=… isNull=…` — Firebase session at process start, immediately after `Firebase.initializeApp`. | `0ddc373` | Also remove the `authStateChanges().listen` block (`DIAG_HANG authStateChanges #N uid=…`). That listener is never cancelled and exists only for logging. Drop the `firebase_auth` and `flutter/foundation` imports added for this (harness wiring in the same file **stays** — see B). |
| `lib/router.dart` | `DIAG_HANG router.redirect inputs loc=… currentUserUid=… authAsync=… prefs.currentUserId=…` plus branch lines `allow-splash`, `loading-no-redirect`, `not-signed-in→/login`, `signed-in→/home`, `no-redirect`. | `0ddc373` | Delete `_diagHangAuthAsyncLabel` and the `authAsync` / `localUid` reads. Drop imports of `sharedPrefsProvider` and `auth_controller.dart`. Keep the pre-existing `Router:` / `RouterProvider:` `debugPrint`s. **Keep** the R4 `sessionNow.isLoading → return null` branch — that is product, not instrumentation. |
| `lib/legacy/screens/splash_screen.dart` | `DIAG_HANG splash.navigate branch=/home\|/login signedIn=… currentUserUid=… authAsync=… prefs.currentUserId=…` | `0ddc373` | Delete the DIAG_HANG block and the extra imports (`foundation`, `sharedPrefsProvider`, `auth_controller.dart`). Keep the pre-existing `SplashScreen:` `debugPrint`s. **Keep** `_tryNavigate` waiting for a terminal session (not loading) after the 1s flag — do not restore `user != null` at T+1s. |
| `lib/features/auth/presentation/controllers/auth_controller.dart` | `DIAG_HANG AuthController.load BEFORE #N uiState=…`, `set-loading #N uiState=loading`, `AFTER #N uiState=loading\|data\|error elapsedMs=…` | `0ddc373` | Delete `_diagHangAuthControllerN`, `_diagHangAuthUiState`, the `foundation` import, and the three log blocks. Leave `load()`'s `state = loading` → `_getCurrent` → `data`/`error` assignment unchanged. |
| `lib/features/auth/presentation/providers/auth_providers.dart` | `DIAG_HANG currentUserProvider branch=data uid=… gateSeesSignedIn=…`, `branch=loading`, `branch=error error=… gateSeesSignedIn=false` | `0ddc373` (strings changed in R4) | Delete the `kDebugMode` / `when()` logging only. **Keep** `currentUserProvider` as `Provider<AsyncValue<User?>>` returning `authControllerProvider.current` unchanged — do **not** restore `loading: () => null` / `error: () => null` (that was the R4 defect). |
| `lib/features/auth/data/repositories/auth_repository_impl.dart` (`getCurrentUser` only) | `DIAG_HANG AuthRepository.getCurrentUser BEFORE`, `AFTER null-auth uiWouldBe=data(null)`, `BEFORE readProfile`, `AFTER readProfile success uiWouldBe=data`, `AFTER readProfile failure uiWouldBe=error` | `0ddc373` | Strip only the DIAG_HANG prints and the `kDebugMode` / `Stopwatch` scaffolding. **Keep** R4: do not await `readProfile` on the return path; catch profile failures and `developer.log(name: 'AuthRepository')` (permanent, not DIAG). Do **not** restore `await profiles.readProfile` + `rethrow`. The `signIn` DIAG_HANG in this same file is a separate `19a1e69` row. |
| `lib/features/chat/data/datasources/chat_firestore_data_source.dart` | `DIAG_HANG chatMessages emission #1\|#2\|#3 baseId=… count=… isFromCache=… hasPendingWrites=… elapsedMs=…` (first three emissions per subscription, then silent) | `0ddc373` | Convert `async*` + `await for` back to `.snapshots(…).map(…)`. **Keep** `includeMetadataChanges: true` (inventory C). **Keep** yielding `ChatMessageBatch(fromCache: snap.metadata.isFromCache)` — do not restore a bare `List<MessageModel>`, and do not AND `hasPendingWrites`. Drop the `Stopwatch`, `emissionN`, `kDebugMode` prints, and the `foundation` import. |

### `19a1e69` set (already in HEAD before `0ddc373`)

These prints are **not** wrapped in `kDebugMode`. `debugPrint` / `developer.log` still execute in profile/release; stripping them is a product fix as well as a cleanup.

| File | What it logs | Commit | Removal notes |
|------|--------------|--------|----------------|
| `lib/features/auth/data/datasources/firebase_auth_remote_data_source.dart` | `DIAG_HANG signInWithEmailAndPassword BEFORE email=…`, `AFTER null-user`, `AFTER success uid=…`, `AFTER throw code=…` | `19a1e69` | The surrounding `try` / `on fb.FirebaseAuthException` is **production** — keep it. Remove only `Stopwatch`, the four `debugPrint`s, the TEMP comment, and the `foundation` import if nothing else needs it. |
| `lib/features/auth/data/repositories/auth_repository_impl.dart` (`signIn` only) | `DIAG_HANG AuthRepository.signIn START`, `remote done elapsedMs=…`, `local.writeCurrentUser AFTER`, `AuthRepository.signIn readProfile returned elapsedMs=…` | `19a1e69` | Strip DIAG_HANG prints only. **Keep** R4 `_readProfileBestEffort` (await + catch + `developer.log(name: 'AuthRepository')`). After both this row and the `getCurrentUser` DIAG row, drop the `foundation` import if unused; keep `dart:developer`. |
| `lib/features/profile/data/datasources/profile_firestore_data_source.dart` | `DIAG_HANG readProfile BEFORE get uid=…`, `AFTER existing-doc`, `AFTER no-auth-for-create`, `BEFORE create-txn`, `AFTER create missing-doc`, `AFTER create-or-return`, `AFTER throw error=…` | `19a1e69` | The whole `try`/`catch (e)`/`rethrow` wrapper was added for logging. Unwrap to the original body (no catch). Drop the `foundation` import. |
| `lib/features/chat/domain/usecases/send_message.dart` | `developer.log(name: 'DIAG_HANG')`: `putBytes BEFORE i=… key=… bytes=…`, `putBytes AFTER success i=… path=…`, `putBytes AFTER throw i=… error=…` | `19a1e69` | The inner `try`/`catch`/`rethrow` around `cloudStorage.putBytes` is logging-only. Restore a bare `putBytes` + `copyWith` inside the existing `guard(...)`. **Keep** `import 'dart:developer' as developer` — the orphan-upload log uses `name: 'SendMessage'`, which is product behaviour. |

### Storage retry-cap readback (after `0ddc373` / `19a1e69`)

| File | What it logs | Removal notes |
|------|--------------|---------------|
| `lib/main.dart` | `DIAG_HANG storageRetryCaps operation=…ms download=…ms upload=…ms` — Dart-side readback of `FirebaseStorage.instance.maxOperationRetryTime` / `maxDownloadRetryTime` / `maxUploadRetryTime` immediately after the three `setMax…RetryTime` calls. | `kDebugMode` block only. **Keep** the three setter calls (product retry caps). Drop only the print and its TEMP comment. |

### `MOONBASE_FAIL_PROFILE` throwaway (not harness)

Forced `FirebaseException` so the R4 `readProfile` catch runs without a real offline/blackhole. **Not** Inventory B. Do not leave the define or the throw.

| File | What it is | Removal notes |
|------|------------|---------------|
| `lib/features/auth/data/repositories/auth_repository_impl.dart` | `_kFailProfileDefine` (`bool.fromEnvironment('MOONBASE_FAIL_PROFILE')`) and a `kDebugMode && _kFailProfileDefine` throw of `FirebaseException(plugin: cloud_firestore, code: unavailable)` immediately before `profiles.readProfile` on the `getCurrentUser` session-restore path. | Delete the const, the throw, the TEMP comments, and the `firebase_core` import if unused. **Keep** the catch + `developer.log(name: 'AuthRepository')`. Do not move this into `firebase_debug_harness.dart`. |

Grep when done: `rg MOONBASE_FAIL_PROFILE lib/` returns nothing.

`test/` contains no `DIAG_HANG` matches. No test edits are required for the strip itself.

---

## Inventory B — Keep, permanently

These look like debug code. They are the harness. Deleting them makes blackhole / force-offline unverifiable.

`MOONBASE_FAIL_PROFILE` is **not** in this list. It is Inventory A throwaway (forced `readProfile` failure). Do not fold it into `firebase_debug_harness.dart`.

| File / site | Why it is permanent |
|-------------|---------------------|
| `lib/core/debug/firebase_debug_harness.dart` (`d192b26`) | The fixture. `MOONBASE_FORCE_OFFLINE` / `MOONBASE_BLACKHOLE` (`kDebugMode` + `--dart-define`), Firestore host override, Storage `useStorageEmulator` to TEST-NET-1 `192.0.2.1:443`. |
| `lib/main.dart` — `applyFirestoreDebugSettings` + `await applyFirebaseDebugNetworkEffects()` (`d192b26`) | Single `Settings` assignment site. Harness must run after `Firebase.initializeApp` and before first Storage/Firestore use. Strip DIAG_HANG from this file; do not strip these two calls. |
| `lib/app.dart` — `moonbaseNetworkDebugBannerLabel` banner (`d192b26`) | On-device proof the define actually armed. Without it, a forgotten `--dart-define` (or a leftover one) is invisible. |
| `README.md` § "Debug network harness" (`d192b26`) | How to run the fixture on a physical Android device. |
| `android/app/src/debug/res/xml/network_security_config.xml` (`0ddc373`) | Permits cleartext **only** to `192.0.2.1`. `base-config cleartextTrafficPermitted="false"` so no other host can downgrade to http. Debug source set only — release has no copy of this file. **Without it, Storage blackhole is an instant cleartext IOException, not a hang.** |
| `android/app/src/debug/AndroidManifest.xml` — `android:networkSecurityConfig="@xml/network_security_config"` (`0ddc373`) | Wires the config in the debug source set. Main/release manifests stay untouched (no `networkSecurityConfig`, no `usesCleartextTraffic`). |

**Comment rewrite (required as part of A, not a deletion):** both Android files currently say `TEMP DIAG_HANG / debug harness — remove with the DIAG_HANG instrumentation`. After the strip, rewrite those comments to "permanent debug-harness support for `MOONBASE_BLACKHOLE`; not throwaway" so a later grep-and-delete pass does not remove them. Then `rg DIAG_HANG android/` should also be empty.

---

## Inventory C — Keep, but for a different reason

| Site | Why it survives |
|------|-----------------|
| `ChatFirestoreDataSource.streamMessages` — `.snapshots(includeMetadataChanges: true)` | Added in `0ddc373` so cache→live metadata-only transitions actually emit (Firestore otherwise suppresses them; emission #1 `isFromCache=true` on an empty-looking cache was a false reading). **R5 formalises this as production behaviour** (domain-level freshness / cache-vs-live, not throwaway logging). Restore `.map(...)` form if you like; **do not** drop the flag. |

Restored shape (logging gone, flag kept, batch mapping kept):

```dart
@override
Stream<ChatMessageBatch> streamMessages(String baseId) {
  return _messagesCol(baseId)
      .orderBy('createdAt')
      .snapshots(includeMetadataChanges: true)
      .map((snap) {
    final list = snap.docs
        .map((d) => MessageModel.fromFirestore(d.id, baseId, d.data()))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return ChatMessageBatch(
      messages: list,
      fromCache: snap.metadata.isFromCache,
    );
  });
}
```

---

## `getCurrentUser` try/catch — strip DIAG, keep R4 session/profile split

`AuthRepositoryImpl.getCurrentUser` had a DIAG-only `try` / `catch` / `rethrow` around `readProfile`. R4 replaced that with: return `Right(User)` after Auth + `writeCurrentUser`, `unawaited` create-or-return, and a **permanent** `developer.log(name: 'AuthRepository')` on profile failure (not behind `kDebugMode`).

Strip DIAG_HANG only. Do **not** restore `await profiles.readProfile` on the return path (that blocks splash) and do **not** `rethrow` into `guard()` (that classifies a profile miss as signed-out).

Restored shape after DIAG strip:

```dart
@override
Future<Either<Failure, User?>> getCurrentUser() =>
    guard(() async {
      final model = await remote.getCurrentUser();
      if (model == null) {
        await local.clear();
        return null;
      }
      await local.writeCurrentUser(model);
      unawaited(_readProfileAfterSessionRestore(model.id));
      return model.toEntity();
    });
```

`_readProfileAfterSessionRestore` (or equivalent) still catches, logs with `name: 'AuthRepository'`, and does not rethrow. `dart:developer` stays.

Related unwraps (same investigation, not R4):

- `ProfileFirestoreDataSource.readProfile` — drop the logging `try`/`catch`/`rethrow` added in `19a1e69`; keep the get → maybe-create-txn → get body.
- `SendMessage._uploadAll` — drop the logging `try`/`catch`/`rethrow` around `putBytes`; keep the outer `guard(...)`.

`FirebaseAuthRemoteDataSource.signIn`'s `on fb.FirebaseAuthException` is production mapping. Do not unwrap that one.

---

## Measurements (capture before deleting the code that produced them)

These numbers are the evidence behind R-suite timeouts. Once DIAG_HANG is gone, they are not reproducible from logs. Copy into the decisions log as well; this table is where they were measured.

| Measurement | Values | What it justifies |
|-------------|--------|-------------------|
| `readProfile` cached-read latency (`DIAG_HANG readProfile AFTER existing-doc elapsedMs=…`) | 63 ms / 10036 ms / 10053 ms / 14939 ms / 14948 ms | The spread is why **R3 is 20 s**. A 10 s ceiling would clip the slow cluster (~15 s) and look like a hang. |
| Firestore online-state ceiling | 10182 / 10217 / 10325 ms | ~10 s is the observed wait for Firestore to declare online on this device/network. Timeout / "still waiting" UX should sit above this, not on it. |
| Chat emission #1 (cached) | 65 / 72 / 84 / 123 ms; consistently `count=15`, `isFromCache=true` | First snapshot is cache and is fast. `isFromCache=true` on #1 is **not** proof the live listen failed — Firestore always raises a cache snapshot first, including when you need #2 to see live. |
| Chat #1 → #2 on a good network | 65 ms → 182 ms | Live follow-up is sub-second when the network is fine. A hang is "no #2", not a slow #1. Needs `includeMetadataChanges: true` (R5) or #2 may never arrive. |
| Storage `-13030` on blackhole | ~95 s before **R2** | Uncapped SDK default (`maxOperationRetryTime` ~2 min). After R2 (15 s native, 20 s `resolveTimeout`) the spinner ends at ~20 s. Device-check tripwire is hang vs instant cleartext, not this duration. |

---

## Verification after removal

Run in this order. The last item is the one that catches a mistaken revert of the cleartext config.

1. **`rg DIAG_HANG lib/` returns nothing.** If anything remains, the strip is incomplete. (`docs/DIAG_HANG_REVERT_PLAN.md` will still match; that is this file.)
2. **`rg DIAG_HANG android/` returns nothing.** If it matches the debug manifest or `network_security_config.xml`, you forgot the comment rewrite in inventory B — rewrite, do not delete the files.
3. **`fvm dart analyze`** (at least the touched libraries, ideally the package) is clean.
4. **Unit suite green:** `fvm flutter test test/features test/core` (merge gate in README).
5. **Rules suite green:** `firestore/tests` via `.\run-tests.ps1` (or `npm test` from that directory).
6. **Blackhole image hang (prominent).** Physical Android only, same recipe as README § "Debug network harness":

   ```powershell
   fvm flutter run -d <physical-android-id> --dart-define=MOONBASE_BLACKHOLE=true
   ```

   Confirm the on-screen banner reads `DEBUG: BLACKHOLE 192.0.2.1:443`. Open a thread with a cloud image (or send one). **Pass:** the image request hangs (a connect attempt, not a local reject). After R2 the spinner ends at ~20 s (`kFirebaseMediaResolveTimeout`; native cap is 15 s) — that duration is product behaviour, not the tripwire. **Fail:** logcat shows `Cleartext HTTP traffic to 192.0.2.1 not permitted` (or any instant `IOException` naming that host). Instant failure means the debug network-security config or its manifest wire-up is gone. Restore inventory B; do not "fix" it by pointing Storage at production.

   Also confirm a **non-blackhole** debug run still talks to real Storage (banner absent). The exemption is IP-scoped to `192.0.2.1`; if some other host starts using cleartext, the `base-config` is wrong.

---

## Naming convention for the next investigation

Recorded so the next hang/triage session does not invent a parallel style.

| Rule | This session |
|------|----------------|
| Prefix `DIAG_<TOPIC>` | `DIAG_HANG` |
| Always behind `kDebugMode` | `0ddc373` followed this. `19a1e69` did not — those prints can reach profile/release. New work must wrap. |
| BEFORE / AFTER shape with `elapsedMs` | Stopwatch started at the operation (or at **subscription** for streams), logged on every exit including throw. |
| Inventory in a revert doc before the session ends | This file. Write it while the measurements and commit hashes are still in working memory. |
| Per-subscription counters and stopwatches, not per-instance | A datasource-level timer/counter survives "open base → back out → open again" and reports `#4` on a stale clock. `async*` (or equivalent listen-time locals) reset on each subscribe. That distinction produced a real misreading until chat logging moved to per-subscription. |
| Cap noisy streams | Chat logged emissions #1–#3 then stopped. Unbounded snapshot logging is not a diagnostic. |
| Do not mix permanent fixture files into the throwaway commit | `0ddc373` did. That is why `git revert` is forbidden here. Next time: harness/config in one commit, `DIAG_*` prints in another. |
| Metadata stays at the data-source boundary | `isFromCache` / `hasPendingWrites` were read for logs only. Domain freshness types belong to R5, not to throwaway instrumentation. |

Suggested next-session prefix examples: `DIAG_AUTH`, `DIAG_STORE`, `DIAG_SNAP`. One topic per prefix so a grep is a complete revert list.
