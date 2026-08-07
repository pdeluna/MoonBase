# Firestore Schema — Week 3

**Status:** Profiles, bases/members/invites/leave, and chat messages → Firestore. Last-accessed is device-local SharedPreferences (keyed by uid).  
**Source of truth for document shape:** this file + checked-in [`firestore.rules`](../firestore.rules).  
**Current schema version:** `1` on every product document.

**Week 4 Tuesday stopping point:** single-device send / persist / relaunch. **Thursday deliverable:** two-device live-sync verification.

---

## Design principles

1. **Dual membership shape** — keep both:
   - `bases/{baseId}.memberUids[]` for cheap rule checks (`uid in memberUids`) and `array-contains` queries (“list my bases”).
   - `bases/{baseId}/members/{uid}` for per-member detail (role, nickname copy, joinedAt).
2. **`schemaVersion` on every document** — integer, starting at `1`. Clients and rules can reject unknown versions; migrations bump the field in place.
3. **Auth UID is the document key** for profiles and member rows (`users/{uid}`, `members/{uid}`). No separate app-generated user id in Firestore paths.
4. **Stories deferred** — collection paths are reserved in comments only; do not create or rule them yet.

---

## Collections

### `users/{uid}` — profile

| Field | Type | Notes |
|-------|------|--------|
| `nickname` | string | Case-sensitive chat label; set at signup / profile edit |
| `themeMode` | string | `"light"` \| `"dark"` |
| `createdAt` | timestamp | Set once on create |
| `schemaVersion` | number | `1` |

**Create path (Tuesday step 3):** on sign-in, create the profile doc if missing — that is the real new-user path.

**Example**

```json
{
  "nickname": "Alice",
  "themeMode": "dark",
  "createdAt": "<timestamp>",
  "schemaVersion": 1
}
```

---

### `bases/{baseId}` — base header

| Field | Type | Notes |
|-------|------|--------|
| `name` | string | Display name |
| `ownerUid` | string | Firebase Auth UID of owner |
| `memberUids` | string[] | All member UIDs including owner; source of truth for membership *membership checks* |
| `createdAt` | timestamp | Set once on create |
| `schemaVersion` | number | `1` |

**Invariant:** owner is always in `memberUids`, and there is a matching `members/{ownerUid}` row with `role: "owner"`.

**Create order (sequential) / committed-state rule evaluation:** Firestore rules evaluate each write against committed DB state, not sibling writes in the same batch/transaction — confirmed on emulator (`firestore/tests/batch_owner_bootstrap.test.js`). Owner-row-on-create is therefore sequential (base, then member row) with a compensating delete; there is a small non-atomic window if the process dies between them. If the owner member write fails and the compensating delete also fails, the client must surface that to the caller (not swallow it); an orphan base with `ownerUid` set but no owner member row can remain until cleaned up. Owner can still delete via rules (`isOwner` reads `ownerUid`). Double-failure recovery is out of scope for Week 3. The same finding applies to `inviteCodes/{code}` create: `isOwner(baseId)` requires the base doc to already be committed (invite + mapping may share a batch with each other, but not with base create).

**Example**

```json
{
  "name": "Family Base",
  "ownerUid": "uid_alice",
  "memberUids": ["uid_alice", "uid_bob"],
  "createdAt": "<timestamp>",
  "schemaVersion": 1
}
```

---

### `bases/{baseId}/members/{uid}` — membership detail

| Field | Type | Notes |
|-------|------|--------|
| `role` | string | `"owner"` \| `"member"` |
| `nickname` | string | Copy of profile nickname at join / last sync — member list UI does not need profile reads |
| `joinedAt` | timestamp | When this uid joined the base |
| `schemaVersion` | number | `1` |

Doc id **must** equal the member’s Auth UID.

**Example**

```json
{
  "role": "member",
  "nickname": "Bob",
  "joinedAt": "<timestamp>",
  "schemaVersion": 1
}
```

---

### `bases/{baseId}/invites/{code}` — invite codes

| Field | Type | Notes |
|-------|------|--------|
| `createdBy` | string | Auth UID of creator (owner) |
| `createdAt` | timestamp | |
| `maxUses` | number \| null | `null` = unlimited |
| `useCount` | number | Starts at `0`; increment on successful redeem |
| `expiresAt` | timestamp \| null | Optional; omit or `null` = no expiry |
| `schemaVersion` | number | `1` |

Doc id is the 6-char invite **code** (not a random UUID). Codes are a **global** namespace (see `inviteCodes/{code}` below); MVP accepts negligible 6-char collision risk and does **not** enforce create-if-absent uniqueness.

**Redeem lookup (MVP — locked):** family-facing string is the bare 6-char code. Client `get`s `inviteCodes/{code}` → `baseId`, then opens `bases/{baseId}/invites/{code}`. Collection-group lookup was rejected (wider list surface + index); see Decisions.

**Redeem transaction:** joiner cannot `get` the base until they are a member. After resolving `baseId` from the mapping, client reads only the invite inside `runTransaction`, appends self via `memberUids` `arrayUnion`, and creates `members/{uid}`. Member-create uses `isMemberAfter` (`getAfter`); base join update invariants unchanged.

**Example**

```json
{
  "createdBy": "uid_alice",
  "createdAt": "<timestamp>",
  "maxUses": 5,
  "useCount": 1,
  "expiresAt": null,
  "schemaVersion": 1
}
```

---

### `inviteCodes/{code}` — global code → base map

| Field | Type | Notes |
|-------|------|--------|
| `baseId` | string | Target base for redeem |
| `schemaVersion` | number | `1` |

Doc id is the same 6-char **code** as `bases/{baseId}/invites/{code}`.

**Create:** written in the **same WriteBatch** as the nested invite doc. `allow create` requires `isOwner(request.resource.data.baseId)` on an **already-committed** base — same committed-state family as owner-row-on-create (rules use `get()` / `isOwner`, not sibling batch writes). See Create order above.

**Read:** signed-in may `get` a single mapping (redeem); **list is denied** (no enumeration).

**Delete:** owner of mapped base; `deleteBase` sweeps invite docs + mappings (missing mapping = success).

**Example**

```json
{
  "baseId": "base_abc",
  "schemaVersion": 1
}
```

---

### `bases/{baseId}/messages/{messageId}` — chat

| Field | Type | Notes |
|-------|------|--------|
| `authorUid` | string | Auth UID of sender |
| `text` | string | Message body; **non-empty**, max **4000** chars (rules + Dart `kMessageMaxLen`) |
| `createdAt` | timestamp | Write via `serverTimestamp()`; pending local null maps to newest-end `DateTime.now()` in the client DS |
| `schemaVersion` | number | `1` |
| `mediaPaths` | string[] | Always present (use `[]` for text-only). 0–4 Storage paths for **this** base: `bases/{baseId}/media/{uuid}.jpg`. Paths only — never download URLs. |

Doc id is **client-generated** (UUID). Stream: `orderBy('createdAt')` + post-map re-sort so pending nulls do not leap from oldest→newest.

**Example (text-only)**

```json
{
  "authorUid": "uid_bob",
  "text": "Hello base",
  "createdAt": "<timestamp>",
  "schemaVersion": 1,
  "mediaPaths": []
}
```

**Example (with media)**

```json
{
  "authorUid": "uid_bob",
  "text": "Look",
  "createdAt": "<timestamp>",
  "schemaVersion": 1,
  "mediaPaths": [
    "bases/base1/media/550e8400-e29b-41d4-a716-446655440000.jpg"
  ]
}
```

---

### Stories — deferred (do not implement)

```
// DEFERRED — do not create, write, or rule yet.
// bases/{baseId}/stories/{storyId}
//   authorUid, mediaKey, caption?, expiresAt, createdAt, schemaVersion
```

---

## Path map (quick reference)

```
users/{uid}
inviteCodes/{code}
bases/{baseId}
bases/{baseId}/members/{uid}
bases/{baseId}/invites/{code}
bases/{baseId}/messages/{messageId}
// bases/{baseId}/stories/{storyId}   — deferred
```

---

## Field naming vs local domain models

Firestore field names follow this cloud shape (Auth-oriented). Local entities may still use `ownerUserId`, `usedCount`, `content`, etc. until codecs map at the data-source boundary:

| Firestore | Local / domain (approx.) |
|-----------|---------------------------|
| `ownerUid` | `ownerUserId` |
| `memberUids` | legacy `memberIds` |
| `createdBy` | `createdByUserId` |
| `useCount` | `usedCount` |
| `authorUid` / `text` | `userId` / `content` |

Do not rename the Firestore fields to match domain without a `schemaVersion` bump.

---

## Security rules (summary)

Full rules: [`firestore.rules`](../firestore.rules) (draft for review).

| Path | Read | Write (high level) |
|------|------|--------------------|
| `users/{uid}` | signed-in | only `request.auth.uid == uid` |
| `bases/{baseId}` | `uid in resource.memberUids` (query-safe; not `get()`/`isMember`) | create: owner + self in `memberUids`; owner full update; non-member may add only self; member may remove only self; delete: owner |
| `members/{uid}` | base member | owner manage; self-create on join; self may update own nickname copy |
| `invites/{code}` | signed-in (redeem) | create/delete: owner; `useCount` bump: signed-in under constraints |
| `inviteCodes/{code}` | signed-in **get** only; **list denied** | create/delete: owner of mapped `baseId`; update denied |
| `messages/{messageId}` | base member | create as self (`text` length 1–4000); author or owner may delete |
| stories | — | not ruled / not shipped |
| `_smoke_tests/**` | signed-in | signed-in (debug probe only) |

**Join / leave / redeem:** Same committed-state rule evaluation as Create order above for `get()` — sibling writes are invisible unless rules use `getAfter`. Joiner member-create uses `isMemberAfter` (`getAfter`) so atomic redeem can project the +1 `memberUids` update. Client **must** use a single `runTransaction` (see Decisions). Leave is also one `runTransaction` (`arrayRemove` self + delete `members/{uid}`); owner leave is refused client-side (ownership transfer deferred). Sequential non-transactional writes can orphan.

**Rules tests:** [`firestore/tests/`](../firestore/tests/) — `@firebase/rules-unit-testing` against the emulator (`npm test` from that folder).

---

## Decisions & deferred

Locked Week 3 choices — do not re-open without a new ADR.

**When a decision un-parks:** see [`FIRESTORE_UPDATE_TRIGGERS.md`](FIRESTORE_UPDATE_TRIGGERS.md) (precise rule/test change per trigger).

### Membership `get()` cost (option A)

`isMember(baseId)` / `isOwner(baseId)` use `get()` on the base doc. Nested reads (`members/*`, `messages/*`) therefore bill **one extra base-doc read per matched document**, not once per query. Accepted MVP cost. No custom claims; no Cloud Functions for this.

### Profile reads (MVP openness)

**ADR:** MVP: any authenticated user may read profiles by uid; authoritative in-base display may use `members.nickname`; post-MVP candidate: shared-base-only.

No rule change from `allow read: if isSignedIn()` on `users/{uid}`.

### Invite redeem lookup — top-level `inviteCodes` (reverses Ba)

**Supersedes** the earlier Ba choice (`baseId:code` share token). Family-facing string is the bare 6-char code; redeem resolves `baseId` via `inviteCodes/{code}`. Chosen over collection-group lookup (option 1) because a single-doc `get` + denied `list` is a tighter surface and needs no index. Codes are a global namespace; MVP accepts collision risk without create-if-absent uniqueness.

### Invite redeem race + client transaction

Rules authorize a **+1 `useCount` bump**; they do **not** guarantee global `maxUses` under contention — the **client transaction** does.

Required repository redeem shape:

`get(inviteCodes/{code})` → `runTransaction`: read invite → check expiry/`maxUses` → increment `useCount` → `arrayUnion` self on `memberUids` → create `members/{uid}` — invite writes atomic in one transaction.

Non-transactional partial writes can orphan. Emulator suite includes a contention/orphan demonstration. No Cloud Function redeem for MVP.

### Message text cap

Rules: `text.size() > 0 && text.size() <= 4000`. Empty text denied (media-only messages come later — separate feature decision). Dart `kMessageMaxLen` / `SendMessage` mirror **4000** — do not diverge. Empty-text-with-media stays denied.

### Message `mediaPaths` (Storage path refs)

**ADR:** Message docs store **Storage object paths** in `mediaPaths: string[]`, not download URLs. Client derives a download reference via the SDK (`ref(storage, path)`) at render time so access still flows through Storage rules. Always write `mediaPaths` (use `[]` for text-only). Rules: list, size ≤ 4, each entry a whole-string match of `bases/{baseId}/media/{uuid}.jpg` (UUID v4 leaf + `.jpg` — Option B + tight leaf). Path builder: Dart `storagePathFor` in `lib/features/media/data/firebase_storage_path.dart` — sole constructor for cloud paths. Picker stays format-open; task 3 compresses diverse image picks to JPEG before upload.

Domain `Message.media` / `MediaRef` round-trip is **lossy** on Firestore: only the path is persisted; width/height/mimeType/sizeBytes/thumbnailKey/duration are not. `fromFirestore` rebuilds image `MediaRef`s with those fields null and `syncStatus: synced`.

### Nickname copy — advisory

`members/{uid}.nickname` is a denormalized copy for list UI. It is **not authoritative**; rules do not require it to match `users/{uid}.nickname`. Drift is acceptable for MVP.

### ThemeMode on profile vs live theming (deferred)

`themeMode` is persisted on the profile doc (`users/{uid}`) but is **not yet** source of truth for live theming — `ThemeController` still uses SharedPreferences (`theme:$uid`). Wiring `ThemeController` to `profile.themeMode` is a **separate task**.

### Owner leave / transfer — deferred

No ownership transfer; no last-owner-leave. Owner cannot use the self-remove branch to abandon a base without orphaning. Out of scope for MVP — do not build.

### Storage access (MVP openness)

**ADR:** Storage reads/writes are gated by `request.auth != null` + object path + size/type only — **not** by base membership. Storage security rules cannot read Firestore documents, so `isMember(baseId)` is impossible here (unlike [`firestore.rules`](../firestore.rules)).

Checked-in rules: [`storage.rules`](../storage.rules). Emulator suite: [`storage/tests/`](../storage/tests/).

**Revisit trigger:** move to custom-claims-based membership gating if media privacy across bases ever becomes a hard requirement. Mirrors the open `users` read ADR above.

### Storage size / compression (10 MB per attachment)

**ADR:** Per-attachment ceiling is **10 MB** against **post-compression** bytes. `storage.rules` uses `request.resource.size < 10 * 1024 * 1024`; Dart `MediaConstraints.imageMaxBytesDefault` mirrors **10 MB** — do not diverge.

Client-side compress/resize before upload is required in MediaRepository (Week 5 task 3); **not** implemented in the rules/path groundwork. The cap is **per attachment**: Storage rules evaluate one object per request and cannot see the message group.

**Message envelope:** `maxMediaPerMessageDefault = 4`, enforced in Firestore rules (`mediaPaths.size() <= 4`) **and** client-side (`SendMessage` / picker) — theoretical put volume ≈ **4 × 10 MB = 40 MB** per message.
### Storage delete denied at MVP

**ADR:** No client `allow delete` on Storage objects. Default-deny. Orphaned media after message delete is a **cleanup** problem (Admin SDK / Cloud Function later), not data loss. Any-auth delete would let any signed-in user wipe media in any base — unscoped and unacceptable for a children's app.

`FirebaseMediaStorage.delete` throws [UnimplementedError] permanently (not a pass-3 stub) — client delete is not part of the pipeline.

**Revisit:** author-scoped delete (uploader identity in metadata) or Admin/CF cleanup when product needs it.

### Storage Content-Type trust

**ADR:** `request.resource.contentType.matches('image/.*')` trusts the **client-supplied** `Content-Type` header; it is not magic-byte / real content validation. Acceptable for MVP.

---

## Storage media path

**Locked shape:** `bases/{baseId}/media/{uuid}.jpg` via Dart `storagePathFor(baseId, uuid)`. Matches [`storage.rules`](../storage.rules) (`bases/{baseId}/media/{fileName}`). Fresh v4 UUID per attachment; leaf always `.jpg`.

Firestorestore message docs store those paths in `mediaPaths` (never bytes, never `https://` download URLs).

### Images-only MVP; video deferred

**ADR:** MVP is images-only (`image/.*`, `.jpg` leaf, 10 MB). Video deferred — would require an extension-aware path builder, `video/.*` Storage rules with a separate cap, and a transcode/thumbnail pipeline; domain model retains video fields (`MediaType.video`, `duration`, `thumbnailKey`) as headroom. Video is also a child-safety decision that deserves its own consideration, not a ride-along on path-format work.

**Task 3 notes:**

- Pass 1 (`FirebaseMediaStorage.putBytes`): always JPEG-compress (1920 long edge, quality 80 + ladder), set `SettableMetadata(contentType: 'image/jpeg')`, upload at `storagePathFor`. Key parse: local `<baseId>/<uuid>.<ext>` or already-canonical cloud path → otherwise `ValidationFailure` (loud; never a malformed path).
- **Pass-2 obligation:** `putBytes` returns `Future` and **throws** typed `Failure`s — it does not return `Either`. Send orchestration **must** wrap every cloud `putBytes` in `guard(...)`. An unguarded call will throw raw and crash the send.
- Pass 3: `resolveUri` for download/render of `bases/...` keys.
- **HEIC:** JPEG normalization + `MediaUnsupportedFailure` fallback is built, but **HEIC is unverified until iOS build day** (Android test device cannot produce HEIC) — test deliberately on iOS.
- **StagedBytesReader (`dart:io` / `file://`):** Pass 2 `SendMessage` reads staged picker bytes via the default `File.fromUri` path. Works on Android; **iOS file-path / staging behavior differs and is unverified until iOS build day** — test deliberately alongside HEIC (send with attachments on a real iOS device).

---

## Indexes (expected)

| Query | Index |
|-------|--------|
| List my bases | Composite: `memberUids` **CONTAINS** + `createdAt` **DESC** — checked in [`firestore.indexes.json`](../firestore.indexes.json) |
| Redeem by code (if collection-group) | Collection group `invites` — confirm fields once redeem path is chosen |
| Messages by time | `messages` orderBy `createdAt` under a base — **single-field auto index**; no composite entry required for Tuesday stream/list |

Deploy indexes with: `firebase deploy --only firestore:indexes --project moonbase-aaff7`

---

## Non-goals for this doc

- No stories collection or rules.
- No uniqueness enforcement on `nickname` at the Firestore layer (Auth UID is identity).
- No membership verification inside Storage rules (requires custom claims + Cloud Function — deferred).
- No signed-URL / Function-mediated Storage access; no per-file uploader tracking yet.
