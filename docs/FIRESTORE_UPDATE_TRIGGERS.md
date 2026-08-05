# Firestore Update Triggers

**Keep next to:** [`FIRESTORE_SCHEMA.md`](FIRESTORE_SCHEMA.md)  
**Rules:** [`../firestore.rules`](../firestore.rules), [`../storage.rules`](../storage.rules)  
**Emulator suite:** [`../firestore/tests/`](../firestore/tests/), [`../storage/tests/`](../storage/tests/) (`.\run-tests.ps1`)

Scale-time reference — when each parked Week 3 / Week 5 decision forces a **rule** and/or **test** change. Each row is *what’s parked, and the precise trigger that un-parks it.* Do not re-open these without hitting the trigger.

Locked decisions (why they’re parked) live in [FIRESTORE_SCHEMA.md → Decisions & deferred](FIRESTORE_SCHEMA.md#decisions--deferred).

---

## Quick map

| # | Parked decision | Un-park when… | First change surface |
|---|-----------------|---------------|----------------------|
| 1 | Membership via `get(base)` | Hot read path multiplies base reads | Rules + claims CF + tests |
| 2 | Invite over-admit allowed by rules | “Never exceed `maxUses`” is hard | Rules + CF redeem + invert test |
| 3 | Open `users` read | Sensitive profiles / shared-base privacy | Rules + new deny test |
| 4 | Message `text` 1–4000 (empty text denied; media-only deferred) | Media-only messages become a product need | Rules allow empty text when `mediaPaths` non-empty; flip empty-text test |
| 5 | Advisory nickname copy | Stale names hurt UX | Fan-out or stricter rules + test |
| 6 | Owner leave / transfer | Handoff/abandon is a feature | Rules transfer branch + tests |
| 7 | `schemaVersion == 1` only | First post-MVP reshape | Rules accept `[1,2]` + coexistence tests |
| 8 | Stories rules commented out | Stories leave local storage | Uncomment + stories deny matrix |
| 9 | Messages rules ahead of feature | Week 4 chat data source lands | Confirm codec + cap mirror |
| 10 | Storage auth-only (no membership) | Media privacy across bases is hard | Claims CF + `storage.rules` + invert tests |
| 11 | Storage delete denied | Author delete or Admin cleanup is a product need | `allow delete` (scoped) or CF + tests |

---

## 1 — Membership via `get(base)`

**Parked as:** option A — `isMember` / `isOwner` call `get()` on the base doc.

**Rules (today):** `firestore.rules` — `isMember` / `isOwner` (~40–50); nested reads that call them (e.g. base read ~97, `members` ~149, `messages` ~252).

**Trigger:** a hot read path multiplies base reads — concretely, Week 4 chat paginating *M* messages does *M* extra base `get()`s, or member lists grow past tens. Watch the usage dashboard for **reads scaling with list size, not query count**.

**Rule change:** `isMember` / `isOwner` read `request.auth.token.baseIds` (custom claims) instead of `get()` — needs a Cloud Function to mint claims on join/leave (**Blaze**).

**Test change:** `authenticatedContext` gains a claims arg; the `get()`-based tests no longer model reality.

---

## 2 — Invite over-admit

**Parked as:** rules authorize a +1 `useCount` bump; client `runTransaction` is the real cap. Suite documents that non-transactional join can over-admit vs `maxUses`.

**Rules (today):** invite update / redeem (~221–243).

**Test (today):** `firestore/tests/firestore.rules.test.js` — `"invite contention…"` asserts over-admit *can* happen (tripwire).

**Trigger:** the moment **“never exceed `maxUses`”** becomes a hard requirement (capped seats). For a family app, likely never.

**Rule change:** revoke client `useCount` writes (owner-only); move redeem to a Cloud Function Admin transaction.

**Test change:** the over-admit test is a tripwire — it currently asserts over-admit happens; when you serialize, that assertion **inverts** to “second join denied.”

---

## 3 — Open `users` read

**Parked as:** MVP ADR — any authenticated user may read profiles by uid.

**Rules (today):** `match /users/{uid}` — `allow read: if isSignedIn();` (~64).

**Trigger:** profiles gain sensitive fields, or privacy shifts to “only people who share a base,” or you leave the closed family circle.

**Rule change:** `isSignedIn()` → shared-base-only (collection-group, denorm, or claims — expensive).

**Test change:** add a “signed-in non-co-member denied reading a profile” case (none today, because it’s intentionally allowed).

---

## 4 — Message cap 4000 + non-empty

**Parked as:** rules enforce `text.size() > 0 && text.size() <= 4000`; empty text denied until media-in-messages. Dart `kMessageMaxLen` / `SendMessage` now mirror **4000**.

**Rules (today):** messages create (~260–262).

**Test (today):** `"messages text cap"` — empty and `4001` rejected; `4000` allowed.

**Trigger (a):** Week 4 chat — `SendMessage` validation must mirror **4000 + non-empty** or they drift.

**Trigger (b):** media-in-messages later — empty text must become allowed when a media ref is present, so `text.size() > 0` becomes “text non-empty **OR** media present,” and the “empty text rejected” test **flips**.

---

## 4b — Profile `themeMode` vs live theming

**Parked as:** `users/{uid}.themeMode` is written (default `light` on create) but `ThemeController` still uses SharedPreferences (`theme:$uid`).

**Trigger:** decide cloud theme is source of truth for UI.

**Change:** wire `ThemeController` to profile `themeMode` (read on session / write on toggle). Separate task — see [FIRESTORE_SCHEMA.md](FIRESTORE_SCHEMA.md) Decisions.

---

## 5 — Advisory nickname copy

**Parked as:** `members/{uid}.nickname` is not authoritative; no sync with `users/{uid}.nickname`.

**Schema:** [FIRESTORE_SCHEMA.md](FIRESTORE_SCHEMA.md) — members + Decisions.

**Trigger:** stale names in member lists become a visible UX problem.

**Rule / impl change:** fan-out update to member copies on profile rename, **or** rules requiring copy == profile (extra `get()` per member write).

**Test change:** add a rename-propagates-to-copies test.

**Timing:** post-MVP polish; not before December.

---

## 6 — Owner leave / transfer deferred

**Parked as:** no ownership transfer; no last-owner-leave; do not build.

**Rules (today):** no transfer path; base update pins `ownerUid` (~117: `request.resource.data.ownerUid == resource.data.ownerUid`).

**Trigger:** “hand off or abandon my base” becomes a feature.

**Rule change:** add a transfer branch (new owner + role swap in **one transaction**).

**Test change:** owner-transfer and last-owner-leave cases.

---

## 7 — `schemaVersion == 1` hard-required everywhere

**Parked as:** every product doc carries `schemaVersion: 1`; rules require `== 1` on create/update.

**Trigger:** the first time you reshape any document post-MVP.

**Rule change:** accept both during migration (`schemaVersion in [1, 2]`).

**Test change:** v1/v2 coexistence.

This is why the field is on every doc — you’re pre-positioned.

---

## 8 — Stories rules commented out

**Parked as:** stories path reserved in comments only; not created, written, or ruled.

**Rules (today):** commented block (~274–282).

**Trigger:** Phase 2 (Weeks 6–12), when Stories moves off local storage. (Still Angelo’s local-only feature today.)

**Rule change:** uncomment + add TTL / archive / media rules.

**Test change:** stories deny matrix.

---

## 9 — Messages rules are ahead of the feature

**Parked as:** messages collection shaped and ruled; nothing in the app writes there yet. Harmless now.

**Trigger:** Week 4 chat cloud swap.

**Action (no speculative redesign):** confirm the data source writes exactly `authorUid`, `text`, `createdAt`, `schemaVersion` and mirrors the **4000** / non-empty cap (see §4).

---

## 10 — Storage auth-only (no membership)

**Parked as:** MVP ADR — Storage gated by signed-in + path + size/type only; no base membership check (Storage rules cannot read Firestore).

**Rules (today):** [`../storage.rules`](../storage.rules) — `bases/{baseId}/media/{fileName}` read/create/update require `request.auth != null` (+ size/type on write).

**Test (today):** [`../storage/tests/storage.rules.test.js`](../storage/tests/storage.rules.test.js).

**Trigger:** media privacy across bases becomes a hard requirement (cross-base signed-in users must not read/write another base’s media).

**Rule change:** custom claims (e.g. `baseIds`) minted by a Cloud Function on join/leave; Storage rules check `request.auth.token` membership for `baseId`.

**Test change:** authenticated contexts gain claims; add “signed-in non-member denied” cases (none today — intentionally allowed).

---

## 11 — Storage delete denied

**Parked as:** MVP ADR — no client `allow delete`; default-deny. Orphans are cleanup, not data loss.

**Rules (today):** [`../storage.rules`](../storage.rules) — no delete allow under media path.

**Test (today):** `"8 signed-in delete under media path denied (MVP)"`.

**Trigger:** author-scoped media delete or Admin/CF orphan cleanup becomes a product need.

**Rule change:** `allow delete` with uploader/owner check (metadata / claims), **or** leave client deny and delete only via Admin SDK / Cloud Function.

**Test change:** invert or add scoped allow + cross-user deny cases.

---

## Related

| Doc / path | Role |
|------------|------|
| [FIRESTORE_SCHEMA.md](FIRESTORE_SCHEMA.md) | Shape + Decisions & deferred |
| [`../firestore.rules`](../firestore.rules) | Checked-in Firestore rules |
| [`../storage.rules`](../storage.rules) | Checked-in Storage rules |
| [`../firestore/tests/`](../firestore/tests/) | Firestore emulator deny/allow matrix |
| [`../storage/tests/`](../storage/tests/) | Storage emulator deny/allow matrix |
| [CLOUD_FIRESTORE_TEST_EXPANSION.md](CLOUD_FIRESTORE_TEST_EXPANSION.md) | Broader cloud test expansion plan |
