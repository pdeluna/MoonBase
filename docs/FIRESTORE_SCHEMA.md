# Firestore Schema — Week 3

**Status:** Profiles, bases/members/invites/leave, chat messages, and calendar (events + per-base `settings/calendar`) → Firestore. Last-accessed is device-local SharedPreferences (keyed by uid).

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
| `text` | string | Message body; max **4000** chars. May be empty only when `mediaPaths` is non-empty |
| `createdAt` | timestamp | Write via `serverTimestamp()`; pending local null maps to newest-end `DateTime.now()` in the client DS |
| `schemaVersion` | number | `1` |
| `mediaPaths` | string[] | Always present (use `[]` for text-only). 0–4 Storage paths for **this** base: `bases/{baseId}/media/{uuid}.jpg`. Paths only — never download URLs. |

Doc id is **client-generated** (UUID). Stream: `orderBy('createdAt')` + post-map re-sort so pending nulls do not leap from oldest→newest.
At least one of trimmed `text` or `mediaPaths` must be non-empty.

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

### `bases/{baseId}/events/{eventId}` — calendar

| Field | Type | Notes |
|-------|------|--------|
| `title` | string | **1–80** chars (rules + Dart `kEventTitleMaxLen`) |
| `startAt` | timestamp | **UTC** instant. All-day events store local midnight of the chosen day converted to UTC. |
| `endAt` | timestamp \| null | Optional; when present must be `>= startAt`. Single-day events only (MVP). |
| `allDay` | bool | Required |
| `notes` | string \| null | Optional; **≤ 500** chars (rules + Dart `kEventNotesMaxLen`) |
| `createdBy` | string | Auth UID of author; `== request.auth.uid` on create; **immutable** |
| `createdAt` | timestamp | `serverTimestamp()`; **immutable** |
| `updatedAt` | timestamp | `serverTimestamp()` on create and on every update |
| `schemaVersion` | number | `1` |

Doc id is **client-generated** (UUID v4, as chat). Create is gated by `settings/calendar.eventCreation` (see below); author **or** owner may update/delete. The creation policy gates *creation only* — a member's own earlier events stay editable/deletable under `owner` (U-1 assumption; rules + emulator test pin it).

Pending local writes carry null `createdAt`/`updatedAt` until the server timestamp resolves; the client codec maps those to `DateTime.now()` (UTC) stand-ins, same as chat.

**Example**

```json
{
  "title": "Dinner at Grandma's",
  "startAt": "<timestamp>",
  "endAt": null,
  "allDay": false,
  "notes": "Bring dessert",
  "createdBy": "uid_bob",
  "createdAt": "<timestamp>",
  "updatedAt": "<timestamp>",
  "schemaVersion": 1
}
```

**Reserved (additive; not written or ruled today):**

```
// bases/{baseId}/events/{eventId}.reminders        — notification offsets (deferred)
// bases/{baseId}/events/{eventId}.attachmentPaths  — member documents / pictures (deferred;
//   the Dart entity already carries an empty `attachments` extension point; the codec never
//   writes it — adding the field extends rules hasOnly + validation, no schemaVersion bump)
```

---

### `bases/{baseId}/settings/{settingId}` — per-kind base settings

Only `settingId == 'calendar'` exists. Owner-write / member-read. The owner writes the **whole** doc on first save (window + policy together) — no partial docs, so the codec only substitutes defaults for the *missing-doc* case.

| Field | Type | Notes |
|-------|------|--------|
| `pastDays` | int | **0–365** (rules + Dart `kCalendarWindowMaxDays`) |
| `futureDays` | int | **0–365** |
| `eventCreation` | string | `"members"` \| `"owner"`. **Missing doc ⇒ `"members"`** — mirrored by rules `eventCreationPolicy()` and Dart `CalendarSettings.defaults` (the one defaults constant). |
| `updatedAt` | timestamp | `serverTimestamp()` |
| `schemaVersion` | number | `1` |

Defaults when the doc is missing: `pastDays 7`, `futureDays 30`, `eventCreation "members"`.

**Example**

```json
{
  "pastDays": 7,
  "futureDays": 30,
  "eventCreation": "members",
  "updatedAt": "<timestamp>",
  "schemaVersion": 1
}
```

**Reserved (comment-only, do not create or rule — same convention as stories):**

```
// bases/{baseId}/settings/notifications  — per-base notification policy (quiet hours,
//                                          default reminder offset); same owner-write shape
// users/{uid}/devices/{deviceId}         — FCM tokens (deferred; needs Cloud Messaging decision;
//                                          profile doc hasOnly stays strict)
```

---

### `bases/{baseId}/reactions/{reactionId}` — reactions (R3, flat per-base)

Doc id is **deterministic**: `{targetKind}:{targetId}:{uid}` — one reaction per `(user, target)` by construction. `set()` upserts (replace kind), `delete()` toggles off; no transaction.

| Field | Type | Notes |
|-------|------|--------|
| `targetKind` | string | Shipped: `message`. Reserved in the Dart enum and denied by rules until their collection exists: `story`, `comment`, `post`, `event`. |
| `targetId` | string | Doc id of the target under the same base; rules `exists()`-check it per kind (`messages/{targetId}` for `message`). |
| `uid` | string | Reactor; `== request.auth.uid` and `==` the id's third segment. |
| `kind` | string | `like` \| `heart` \| `laugh` \| `wow` \| `sad` \| `fire` — mirrors Dart `ReactionKind`; the emulator test pins the six. |
| `createdAt` | timestamp | Write via `serverTimestamp()`; rewritten on replace (it is the ordering field for the chat listener). |
| `schemaVersion` | number | `1` |

`hasOnly([targetKind, targetId, uid, kind, createdAt, schemaVersion])`. Target docs are never modified — `messages` keeps `allow update: if false`.

**Example**

```json
{
  "targetKind": "message",
  "targetId": "550e8400-e29b-41d4-a716-446655440000",
  "uid": "uid_bob",
  "kind": "heart",
  "createdAt": "<timestamp>",
  "schemaVersion": 1
}
```

**Chat listener query:** `reactions.where('targetKind', isEqualTo: 'message').orderBy('createdAt', descending: true).limit(500).snapshots(includeMetadataChanges: true)` — one listener per chat screen, joined client-side by `targetId` in the chat VM. Requires the composite index below.


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
bases/{baseId}/events/{eventId}
bases/{baseId}/settings/calendar
bases/{baseId}/reactions/{targetKind}:{targetId}:{uid}
// bases/{baseId}/settings/notifications — reserved (deferred)
// users/{uid}/devices/{deviceId}        — reserved (deferred)
// bases/{baseId}/stories/{storyId}      — deferred
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
| `messages/{messageId}` | base member | create as self (`text` length 0–4000; text or media required); author or owner may delete |
| `events/{eventId}` | base member | create: `mayCreateEvent()` (member, and `settings/calendar.eventCreation == 'members'` or owner) as self, title 1–80, notes ≤ 500, `endAt >= startAt`; update: author or owner (`createdBy`/`createdAt` immutable); delete: author or owner |
| `settings/{settingId}` | base member | create/update: owner, `settingId == 'calendar'` only, 0–365 window, `eventCreation in ['members','owner']`; delete: owner (`deleteBase` sweep) |
| `reactions/{targetKind}:{targetId}:{uid}` | base member | create/update as self only, id must equal `targetKind:targetId:uid`, `kind` in the six, `targetKind` shipped, target `exists()`; delete: self or owner |
| stories | — | not ruled / not shipped |
| `_smoke_tests/**` | signed-in | signed-in (debug probe only) |

**Join / leave / redeem:** Same committed-state rule evaluation as Create order above for `get()` — sibling writes are invisible unless rules use `getAfter`. Joiner member-create uses `isMemberAfter` (`getAfter`) so atomic redeem can project the +1 `memberUids` update. Client **must** use a single `runTransaction` (see Decisions). Leave is also one `runTransaction` (`arrayRemove` self + delete `members/{uid}`); owner leave is refused client-side (ownership transfer deferred). Sequential non-transactional writes can orphan.

**Rules tests:** [`firestore/tests/`](../firestore/tests/) — `@firebase/rules-unit-testing` against the emulator (`npm test` from that folder).

---

## Decisions & deferred

Locked Week 3 choices — do not re-open without a new ADR.

**When a decision un-parks:** see [`FIRESTORE_UPDATE_TRIGGERS.md`](FIRESTORE_UPDATE_TRIGGERS.md) (precise rule/test change per trigger).

**Hang / transport measurements, red herrings, network posture:** [`RESILIENCE_DECISIONS.md`](RESILIENCE_DECISIONS.md). This section stays document-shape ADRs.

### Android Wi‑Fi Auth hang — dual-stack IPv6 (SDK bump)

**Root cause (confirmed):** Fresh-install email/password sign-in hung on some dual-stack Wi‑Fi networks (immediate on cellular; Wi‑Fi worked after a successful cellular login). Not SHA/Play Integrity, not emulator wiring, not an app architecture bug. Matches Firebase Android Auth release notes: long IPv6 timeouts blocked IPv4 fallback.

**Fix:** Lockstep FlutterFire bump so Android BoM pulls Auth **24.2.0** — `firebase_core ^4.13.0` (BoM **34.17.0**), `firebase_auth ^6.5.7`, `cloud_firestore ^6.8.0`, `firebase_storage ^13.4.6`. No REST Auth client, Cloud Function broker, or custom-token fallback.

**Verification obligation:** Cold sign-in on the **home** dual-stack Wi‑Fi is the Auth proof (see [`RESILIENCE_DECISIONS.md`](RESILIENCE_DECISIONS.md) § Network posture). Firestore **26.5.0** and Storage **22.0.1** (same BoM) do **not** carry an equivalent explicit dual-stack IPv6 fix — also verify chat sync and media load on that same Wi‑Fi after the bump. A clean run on an IPv4-only network is not that proof.

### R3 — create-or-return write stays unbounded

**Parked as:** R3 Pass 2 wraps **get-only** Firestore reads with `guardWithTimeout` (20s, sized from cache-fallback `readProfile` gets). First-sign-in / new-device `readProfile` create-or-return (`runTransaction` set + follow-up get) is a **write**. It stays unbounded.

That is the accepted new-device limitation: a missing `users/{uid}` doc still waits on server ack for the create. Same class of hang as chat send (Firestore write future does not complete until the server acknowledges).

**Un-park trigger:** when we bound writes. A write-sized budget is a different constant and a different task. Do not reuse `kGuardTimeout` (20s, get-sized) on writes — it would interact with the known send-hang and with Storage upload (native 60s).

**Not a rules change.** Dart I/O helper only.

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

Rules: `text.size() <= 4000` and at least one of text or `mediaPaths` must
be non-empty. The media-only trigger fired when cloud chat attachments landed;
rules now mirror Dart `isValidMessageInput` / `SendMessage`. Empty text with an
empty path list remains denied.

### Message `mediaPaths` (Storage path refs)

**ADR:** Message docs store **Storage object paths** in `mediaPaths: string[]`, not download URLs. Client derives a download reference via the SDK (`ref(storage, path)`) at render time so access still flows through Storage rules. Always write `mediaPaths` (use `[]` for text-only). Rules: list, size ≤ 4, each entry a whole-string match of `bases/{baseId}/media/{uuid}.jpg` (UUID v4 leaf + `.jpg` — Option B + tight leaf). Path builder: Dart `storagePathFor` in `lib/features/media/data/firebase_storage_path.dart` — sole constructor for cloud paths. Picker stays format-open; task 3 compresses diverse image picks to JPEG before upload.

Domain `Message.media` / `MediaRef` round-trip is **lossy** on Firestore: only the path is persisted; width/height/mimeType/sizeBytes/thumbnailKey/duration are not. `fromFirestore` rebuilds image `MediaRef`s with those fields null and `syncStatus: synced`.

### Nickname copy — advisory

`members/{uid}.nickname` is a denormalized copy for list UI. It is **not authoritative**; rules do not require it to match `users/{uid}.nickname`. Drift is acceptable for MVP.

### ThemeMode on profile vs live theming (deferred)

`themeMode` is persisted on the profile doc (`users/{uid}`) but is **not yet** source of truth for live theming — `ThemeController` still uses SharedPreferences (`theme:$uid`). Wiring `ThemeController` to `profile.themeMode` is a **separate task**.

### Owner leave / transfer — deferred

No ownership transfer; no last-owner-leave. Owner cannot use the self-remove branch to abandon a base without orphaning. Out of scope for MVP — do not build.

### Calendar — Home grid, window, creation policy (2026-09-27)

**ADR:** The Home tab of a base draws a **week/month grid** (custom widgets over the same feed — no third-party calendar package, no `intl` — `MaterialLocalizations` formats dates) of events inside a **rolling window** the owner configures: `pastDays`/`futureDays`, defaults **7 / 30**, each clamped **0–365**. The week/month control only changes drawing; it does not change the saved window. Events are single-day with optional end time; caps **title 80 / notes 500**. Times are stored **UTC** and displayed **device-local**; there is no per-base time zone (all-day events store local midnight → UTC, so a member in a different zone may see the day shift — accepted for a family app on one home network).

**Who may create:** `settings/calendar.eventCreation` — `members` (default) or `owner`. The policy gates **creation only**; a member may still edit/delete their **own** earlier events under `owner` (author rule unchanged). UI derives FAB visibility from `CalendarSettings.canCreate(user, base)`; the `CreateEvent` use case re-checks the same object; rules enforce it independently via `mayCreateEvent()` (+1 `get()` on the settings doc per create — create-only, accepted).

**Why a `settings` subcollection, not fields on `bases/{baseId}`:** the base update rule has three branches (owner / join / leave) reasoning about `name` and `memberUids`; extra keys widen every branch and the join transaction's projected state. A per-kind settings doc is owner-write / member-read with a five-line rule, costs one extra read on calendar open, and gives notifications its own `settings/notifications` doc later without touching base rules. No settings write on base create — the sequential owner-bootstrap and its compensating delete are untouched; missing doc ⇒ `CalendarSettings.defaults`.

**Query:** `where('startAt' >= from).where('startAt' < to).orderBy('startAt').limit(200)` — range + orderBy on the **same single field** ⇒ **no composite index**; `firestore.indexes.json` unchanged. `limit(200)` is a client safety cap surfaced as a banner, not pagination.

**Delete sweep:** `deleteBase` pages through `events` and `settings` in addition to `invites`/`members`.

**Notifications (data architecture only — nothing built):** every event carries `startAt`, `updatedAt`, `createdBy`, and a stable client UUID, enough for a Cloud Function `onWrite` trigger or a client scheduler to key reminders idempotently; `settings/notifications` and `users/{uid}/devices/{deviceId}` paths are reserved; `WatchEvents` returns a domain stream a future `ReminderScheduler` can consume without touching the data source. Delivery mechanism (FCM via Functions/Blaze vs device-local vs defer) is **undecided** — U-7.

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

### Reactions — "chat untouched" un-parked (D-19); storage R3 flat per-base collection (D-20)

**Supersedes** the Phase 3 blueprint lock "reactions target `post` and `story` only; chat-message reactions out of scope" (`PHASE3_POSTS_STORIES_REACTIONS_BLUEPRINT.md` §1). Decided 2026-09-27 (plan rev 2): reactions are a **generalized** system usable across chat, stories, and comments; `message` is the first shipped target kind, the others stay reserved (enum + rules `exists()` mapping) until their collections exist.

**Storage — R3 chosen** over R1 (counters/maps on the target doc) and R2 (`reactions` subcollection under each target): a single flat `bases/{baseId}/reactions` collection with deterministic ids.

- **Why not R1:** would require `allow update` on `messages` (today `false`) and a per-target read-modify-write for every tap — two things that must agree (counter vs rows) and a rules widening on the hottest write path.
- **Why not R2:** one listener per visible message (N snapshots for a chat screen) or a collection-group query with its own index and a cross-base read surface.
- **R3 cost:** one listener per chat screen (`targetKind == 'message'`, `orderBy createdAt desc`, `limit 500`) and **one composite index** `reactions (targetKind ASC, createdAt DESC)` — checked into `firestore.indexes.json`; **Philip deploys it manually** and the first live query fails with `failed-precondition` until the Console shows **Enabled**. The repository maps that code to a typed `Failure` so the chat screen degrades to "no chips", never a crash.
- **Invariant:** one reaction per `(user, target)`, enforced by the id shape (no transaction, no uniqueness query). Same kind again ⇒ `delete()` (toggle off); different kind ⇒ `set()` (replace). Encoded once in the `ToggleReaction` use case and once in rules (id + `uid` checks); the emulator suite pins both.
- **Membership cost:** `isMember` on read bills one base `get()` per matched reaction (trigger #1, accepted).

**Not decided here:** owner moderation UI (rules allow owner delete; UI may ship later), reactions on stories/comments/events (each needs its `exists()` branch + tests), aggregated counters (would be R1 and a new ADR).

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
| Calendar window | `events` range (`>=`, `<`) + orderBy on `startAt` under a base — **single-field auto index**; no composite entry |
| Reactions for a chat screen | Composite: `reactions` `targetKind` **ASC** + `createdAt` **DESC** — checked in [`firestore.indexes.json`](../firestore.indexes.json); **manual deploy by Philip**, wait for **Enabled** before the reactions device gate |

Deploy indexes with: `firebase deploy --only firestore:indexes --project moonbase-aaff7`

---

## Non-goals for this doc

- No stories collection or rules.
- No uniqueness enforcement on `nickname` at the Firestore layer (Auth UID is identity).
- No membership verification inside Storage rules (requires custom claims + Cloud Function — deferred).
- No signed-URL / Function-mediated Storage access; no per-file uploader tracking yet.
