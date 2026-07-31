# Week 3 — Firestore profiles + bases (PR summary)

**Branch:** `feature/firebase-integration`  
**Scope:** Persist profiles and bases/members/invites/leave to Cloud Firestore behind existing repositories. Chat/messages remain local (Week 4).  
**Canonical docs:** [`FIRESTORE_SCHEMA.md`](FIRESTORE_SCHEMA.md), [`FIRESTORE_UPDATE_TRIGGERS.md`](FIRESTORE_UPDATE_TRIGGERS.md), [`../firestore.rules`](../firestore.rules)

---

## Summary

Week 3 moves product data (except chat) onto Firestore with checked-in rules, an emulator deny-matrix suite, and Flutter data-layer swaps that keep domain/use-case surfaces stable.

| Area | Outcome |
|------|---------|
| Schema + rules | `schemaVersion: 1` shape documented; `firestore.rules` + indexes checked in |
| Rules tests | Standalone `@firebase/rules-unit-testing` suite under `firestore/tests/` |
| Profiles | `ProfileFirestoreDataSource` — create-or-return on sign-in via Auth |
| Bases | `BaseFirestoreDataSource` — create/list/rename/delete, members, invites, join, leave |
| Invites | Bare 6-char codes via top-level `inviteCodes/{code}` → `baseId` |
| Last-accessed | Device-local SharedPreferences keyed by uid (not a Firestore field) |
| Chat | Still SharedPreferences — deferred to Week 4 |

---

## What shipped

### Tuesday — schema, rules, profiles

- Authored [`docs/FIRESTORE_SCHEMA.md`](FIRESTORE_SCHEMA.md) from the locked document shape (dual membership: `memberUids[]` + `members/{uid}`).
- Checked in [`firestore.rules`](../firestore.rules) covering users, bases, members, invites, messages (rules ready for Week 4), smoke-test path.
- Emulator rules suite: owner-create, join/leave constraints, redeem expiry/`maxUses`, non-member denies, profile A≠B write deny, invite over-admit demonstration.
- Recorded locked decisions + deferred update triggers ([`FIRESTORE_UPDATE_TRIGGERS.md`](FIRESTORE_UPDATE_TRIGGERS.md)).
- Wired `ProfileFirestoreDataSource` create-on-read; Auth ensures profile after successful sign-in / session restore.
- `themeMode` persisted on profile doc but **not** wired into live `ThemeController` (still prefs) — separate follow-up.

### Thursday — bases / members / invites / leave

- `BaseFirestoreDataSource` behind `BaseRepository` (DI in `main.dart`).
- Create base: sequential owner bootstrap (base doc → owner member row) with compensating delete on failure.
- List bases: `memberUids` `array-contains` + `createdAt` desc (composite index in `firestore.indexes.json`).
- Invite create: nested invite + `inviteCodes/{code}` mapping in the same WriteBatch.
- Redeem: resolve code via mapping → single `runTransaction` (invite bump + `arrayUnion` + member create).
- Leave: single `runTransaction` (`arrayRemove` + delete member); owner leave refused client-side.
- Delete base: sweeps members, invites, and invite-code mappings.
- UI: create/join/delete dialogs **await** the repository call **before** `Navigator.pop`, then invalidate providers.
- Last-accessed restore so account switches on the same device reopen the correct base without a sidebar pick.
- Live device verify: User B joined User A’s base successfully.

---

## Critical notes (flagged during Week 3 — do not re-litigate without ADR)

These are the process locks that reviewers and Week 4 should treat as ground truth.

### 1. Rules evaluate **committed** state, not sibling writes

Firestore security rules see the database **after prior commits**, not other writes in the same batch/transaction (unless rules use `getAfter` / `existsAfter`).

**Implications we shipped:**

- Owner bootstrap is **sequential** (base, then owner member), not one atomic batch — with a **compensating delete** if the member write fails. Small non-atomic window if the process dies mid-way; double-failure recovery is out of scope for Week 3.
- `inviteCodes/{code}` create requires `isOwner(baseId)` on an **already-committed** base (invite + mapping may share a batch with each other, not with base create).
- Emulator proof: `firestore/tests/batch_owner_bootstrap.test.js`.

### 2. List-my-bases query requires query-safe base read

`allow read` on `bases/{baseId}` uses `request.auth.uid in resource.data.memberUids` (direct field check).  
**Do not** gate that list query on `isMember` / `get()` — those patterns break `array-contains` queries.

### 3. Join redeem uses `getAfter` for member create

Joiner member-create rules use `isMemberAfter` (`getAfter`) so the atomic redeem transaction can project the +1 `memberUids` update. Client **must** keep redeem in a **single `runTransaction`**. Sequential non-transactional writes can orphan.

### 4. Invite UX is bare 6-char codes (`inviteCodes`) — reverses Ba

- Family-facing string = **6-char code only** (not `baseId:code` share tokens).
- Lookup: `get(inviteCodes/{code})` → `baseId` → nested `bases/{baseId}/invites/{code}`.
- `inviteCodes` allow **get**; **list denied**.
- Collection-group invite lookup was rejected (wider list surface + index).
- Global namespace; MVP accepts collision risk without create-if-absent uniqueness.

### 5. Rules authorize `useCount +1`; client transaction enforces `maxUses`

Under contention, two non-transactional bumps from a stale read can both succeed (over-admit). Documented + covered in the emulator suite. No Cloud Function redeem for MVP.

### 6. Membership `get()` fan-out is accepted MVP cost

Nested reads that call `isMember` / `isOwner` bill **one extra base-doc read per matched document**. No custom claims / Cloud Functions for Week 3. Un-park trigger: see update triggers doc.

### 7. UI must await mutations before dismissing dialogs

Create / join / delete dialogs must `await` the use case **before** `Navigator.pop`, then `invalidate` list providers. Popping early races the UI against incomplete writes.

### 8. Last-accessed is device-local, per uid

Stored in SharedPreferences (`mb.lastAccessedBase.{uid}`), not on `users/{uid}`. Selection and last-accessed are only applied when the base is in the **current user’s** base list (no cross-account leak in-session).

### 9. Deploy target vs emulator project id

- Live Firebase project: **`moonbase-aaff7`**.
- Emulator / rules tests use **`demo-moonbase`**.
- Always pass `--project moonbase-aaff7` for live deploy (`.firebaserc` default may be the demo id):

```powershell
firebase deploy --only firestore:rules --project moonbase-aaff7
firebase deploy --only firestore:indexes --project moonbase-aaff7
```

### 10. Parked / deferred (do not build in this PR)

| Item | Status |
|------|--------|
| Chat / messages → Firestore | Week 4 |
| `ThemeController` ← `profile.themeMode` | Separate task |
| Owner leave / ownership transfer | Deferred (no last-owner-leave) |
| Stories collections + rules | Deferred (comments only) |
| Profile reads limited to shared-base | Post-MVP candidate |
| Message `SendMessage` 4000 cap in Dart | Mirror rules when chat swaps (`text` length 1–4000) |

---

## Test plan

- [ ] `firestore/tests`: `npm test` (rules deny matrix + bootstrap + invite contention notes)
- [ ] `flutter test` (bases/profile/sidebar coverage touched by this branch)
- [ ] Manual: sign up / sign in → profile doc created under `users/{uid}`
- [ ] Manual: User A creates base → appears in list; rename/delete as owner
- [ ] Manual: User A creates invite → User B redeems bare 6-char code → both see base
- [ ] Manual: User B leaves base; owner cannot leave via leave path
- [ ] Manual: select base as User A → sign out → User B → sign out → User A restores last base
- [ ] Confirm live rules/indexes deployed to **`moonbase-aaff7`**

---

## Suggested PR title

`feat(firestore): Week 3 profiles, bases, invites, and rules`

## Suggested PR body (short)

```markdown
## Summary
- Persist profiles and bases/members/invites/leave to Firestore behind existing repositories
- Ship schema doc, firestore.rules, indexes, and emulator deny-matrix suite
- Bare 6-char invites via inviteCodes mapping; last-accessed is device-local per uid
- Chat remains local (Week 4)

## Critical reviewer notes
- Rules see committed state only — owner bootstrap is sequential + compensating delete
- Base list read rule must stay query-safe (`resource.data.memberUids`)
- Redeem/leave are single runTransactions; joiner member-create uses getAfter
- Deploy live rules/indexes with `--project moonbase-aaff7`

## Test plan
See docs/WEEK3_PR_SUMMARY.md
```
