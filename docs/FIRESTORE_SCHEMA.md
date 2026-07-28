# Firestore Schema — Week 3

**Status:** Profiles → Firestore wired (`ProfileFirestoreDataSource` + Auth ensure-read). Bases/members/invites still local.  
**Source of truth for document shape:** this file + checked-in [`firestore.rules`](../firestore.rules).  
**Current schema version:** `1` on every product document.

Write this shape down before any repository swap. Thursday’s membership rules and the bases/members/invites migration depend on it.

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

**Create order:** write the base doc first, then the owner `members/{uid}` row. Rules use `get()` on the base, so a same-batch create of base + member will not see the pending base write.

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

Doc id is the human-shareable **code** (not a random UUID).

**Redeem lookup:** path is nested under `baseId`. Prefer either (a) codes that encode/carry `baseId`, or (b) a collection-group query on `invites` with a composite index. Document the chosen approach when implementing Thursday’s invite swap.

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

### `bases/{baseId}/messages/{messageId}` — chat (later this week / Thursday)

| Field | Type | Notes |
|-------|------|--------|
| `authorUid` | string | Auth UID of sender |
| `text` | string | Message body; **non-empty**, max **4000** chars (enforced in rules; mirror in `SendMessage` when chat swaps) |
| `createdAt` | timestamp | |
| `schemaVersion` | number | `1` |

Keep this collection in the schema now so rules and indexes land with bases; repository swap can follow profiles.

**Example**

```json
{
  "authorUid": "uid_bob",
  "text": "Hello base",
  "createdAt": "<timestamp>",
  "schemaVersion": 1
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
| `bases/{baseId}` | `uid in memberUids` | create: owner + self in `memberUids`; owner full update; non-member may add only self; member may remove only self; delete: owner |
| `members/{uid}` | base member | owner manage; self-create on join; self may update own nickname copy |
| `invites/{code}` | signed-in (redeem) | create/delete: owner; `useCount` bump: signed-in under constraints |
| `messages/{messageId}` | base member | create as self (`text` length 1–4000); author or owner may delete |
| stories | — | not ruled / not shipped |
| `_smoke_tests/**` | signed-in | signed-in (debug probe only) |

**Join / leave / redeem:** Firestore rules do not see other writes in the same batch and do not serialize multi-doc redeem. Client **must** use a single `runTransaction` (see Decisions). Sequential non-transactional writes can orphan.

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

### Invite redeem race + client transaction

Rules authorize a **+1 `useCount` bump**; they do **not** guarantee global `maxUses` under contention — the **client transaction** does.

Required repository redeem shape (when wired — not in this rules pass):

`runTransaction`: read invite + base → check expiry/`maxUses` → increment `useCount` → append `memberUids` → create `members/{uid}` — **all in one transaction**.

Non-transactional partial writes can orphan (e.g. `memberUids` updated without `members/{uid}`, or invite burned without membership). Emulator suite includes a contention/orphan demonstration. No Cloud Function redeem for MVP.

### Message text cap

Rules: `text.size() > 0 && text.size() <= 4000`. Empty text denied (media-only messages come later). When `SendMessage` gains Firestore validation, mirror **4000** there — do not diverge.

### Nickname copy — advisory

`members/{uid}.nickname` is a denormalized copy for list UI. It is **not authoritative**; rules do not require it to match `users/{uid}.nickname`. Drift is acceptable for MVP.

### ThemeMode on profile vs live theming (deferred)

`themeMode` is persisted on the profile doc (`users/{uid}`) but is **not yet** source of truth for live theming — `ThemeController` still uses SharedPreferences (`theme:$uid`). Wiring `ThemeController` to `profile.themeMode` is a **separate task**.

### Owner leave / transfer — deferred

No ownership transfer; no last-owner-leave. Owner cannot use the self-remove branch to abandon a base without orphaning. Out of scope for MVP — do not build.

---

## Indexes (expected)

| Query | Index |
|-------|--------|
| List my bases | `bases` where `memberUids` **array-contains** `uid` (single-field; usually auto) |
| Redeem by code (if collection-group) | Collection group `invites` — confirm fields once redeem path is chosen |
| Messages by time | `messages` orderBy `createdAt` under a base (single-field; usually auto) |

Add `firestore.indexes.json` entries when the first repository that needs a composite index lands.

---

## Non-goals for this doc

- No repository / codec implementation (Tuesday step 3).
- No stories collection or rules.
- No Storage object paths (media remains Phase 3 / later cloud media).
- No uniqueness enforcement on `nickname` at the Firestore layer (Auth UID is identity).
