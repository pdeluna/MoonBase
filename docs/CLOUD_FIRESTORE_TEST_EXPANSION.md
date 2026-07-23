# Cloud / Firestore Persistence — Test Expansion Plan

**Status:** Deferred until product data (profiles, bases, members, invites, chat) is persisted in Firestore.  
**Current build (Week 2):** Firebase Auth is live; bases/invites/members/chat/profiles remain **SharedPreferences / local files**. Firestore is used only for the `_smoke_tests` debug probe.

Use this document when implementing Week 3+ cloud persistence so test coverage expands with the data layer—not after the fact.

---

## 1. What is appropriate *today* (do not over-test cloud yet)

| Area | Current tests | Fit for local+Auth build? |
|------|---------------|---------------------------|
| Auth use cases (`SignIn`, `SignUp` + nickname) | `test/features/auth/domain/usecases/` | Yes — validation + repo delegation |
| Auth repository (remote mock + local cache) | `auth_repository_impl_test.dart` | Yes — mirrors Firebase → SharedPreferences session |
| Auth local DS / profile consistency | `auth_local_data_source_impl_test.dart` | Yes — local profile keys |
| Firebase nickname helpers | `firebase_auth_remote_data_source_test.dart` (email → nickname only) | Partial — no live Firebase / Emulator yet |
| Bases / invites / chat / profile (features) | Use-case + local repo / controller tests | Yes — local-only contracts |
| Media | Local storage + picker tests | Yes — Phase 3 local-first |
| Legacy (`test/legacy/**`) | Mixed; **12 failures** (sidebar needs `authRepositoryProvider` override; 1 `all_models` assertion) | Stale — quarantine or fix; not a cloud signal |

**CI recommendation until cloud lands:** treat `test/features/**` + `test/core/**` as the merge gate; keep `test/legacy/**` non-blocking or excluded.

---

## 2. Gaps already visible in the Auth layer (expand before or with cloud)

These matter even while data is local; they become more important once Auth UIDs gate Firestore.

| Gap | Suggested tests | Why |
|-----|-----------------|-----|
| Firebase exception mapping | Unit tests (fake `FirebaseAuth` / wrapper) for `too-many-requests`, `email-already-in-use`, `invalid-credential`, `network-request-failed` | Scale / rate-limit and clear UX |
| `displayName` preference | Assert `_toModel` / sign-in path prefers Firebase `displayName` over email local-part | Nickname on signup must survive re-login |
| `SignOut` / `GetCurrentUser` use cases | Dedicated use-case tests (currently thin vs SignIn/SignUp) | Session correctness for rules |
| `AuthController` | Loading → data/error; double-submit; sign-out during load | Presentation races at scale |
| Signup nickname → chat label | Widget or thin integration: sign-up writes nickname; `memberPresentationProvider` returns it for that UID | End-to-end label path on one device |

---

## 3. When Firestore persistence ships — expand by collection / feature

Assume repositories gain a non-null `remote` (or Firestore data sources) while keeping local cache / outbox where designed.

### 3.1 Profiles → Firestore (Week 3 primary unlock)

| Test layer | What to add |
|------------|-------------|
| Unit — `ProfileRemoteDataSource` / codec | Serialize/deserialize profile docs; nickname, avatar, `updatedAt`; reject malformed docs safely |
| Unit — `ProfileRepositoryImpl` | Remote write + local mirror; remote null → clear; conflict / last-write-wins policy as designed |
| Emulator — Auth + Firestore | User A writes `users/{uid}`; User B cannot write A’s profile (rules) |
| Emulator — read | Authenticated user can read profiles of **members of shared bases** only (once membership rules exist)—or public-within-base policy as documented |
| Manual / integration | Nickname set at signup appears on **second device** after cloud sync |

### 3.2 Bases, members, invites

| Test layer | What to add |
|------------|-------------|
| Unit — remote DS | Create base, membership row, invite doc; `usedCount` / expiry / maxUses on redeem |
| Unit — repository | Join increments usage atomically (or transaction); idempotent re-join; leave/delete cascading as designed |
| Emulator — rules | **Owner** create invite; **member** read own base; **non-member** denied on `bases/{id}` and nested chat |
| Emulator — invite negatives | Invalid code, expired, depleted, already-member |
| Multi-UID | N concurrent joins with distinct Auth UIDs → N membership docs, no UID collision |
| Two-device | Owner creates base+invite on device A; member redeems on B; both `listBases` show the same base |

### 3.3 Chat (and later stories/posts)

| Test layer | What to add |
|------------|-------------|
| Unit — message codec + remote DS | Text + media refs; `syncStatus` / outbox transitions (`localOnly` → `synced`) |
| Unit — repository | Send writes remote; stream/list merges remote; failure does not corrupt local |
| Emulator — rules | Only base members can read/write `bases/{baseId}/messages` (or equivalent path) |
| Emulator — realtime | Two Auth clients in same base see each other’s messages without SharedPreferences sharing |
| Scale smoke | Burst send / list pagination under rules (not load-test Firebase quotas in CI—bounded Emulator scenarios) |

### 3.4 Media (Storage)

| Test layer | What to add |
|------------|-------------|
| Unit — `CloudMediaStorage` | Put/resolve/delete against Storage emulator or mocked SDK |
| Rules | Object paths scoped by `baseId` + Auth; non-member download denied |
| Integration | Chat message with Storage URL re-resolves after reinstall (unlike Phase 3 local-only) |

### 3.5 Security rules (checked-in `firestore.rules` / `storage.rules`)

| Test type | What to prove |
|-----------|----------------|
| Rules unit (`@firebase/rules-unit-testing` or Flutter Emulator harness) | Unauthenticated deny-all on product collections |
| | Authenticated non-member cannot read foreign base |
| | Member can read; owner-only paths (delete base, create invite) enforced |
| | `_smoke_tests` either removed, locked to Auth, or left debug-only and documented |
| Regression | Every new collection ships with matching rule tests in the same PR |

### 3.6 Cross-cutting cloud concerns

| Concern | Tests to add |
|---------|----------------|
| Offline / outbox | Queue while offline; replay with idempotency keys; no duplicate messages/members |
| Auth state change | Sign-out cancels listeners; sign-in as other user does not leak prior user’s cache |
| Migration | One-time local → cloud import (if any) is tested and idempotent |
| Nickname at scale | Concurrent profile updates; handle uniqueness policy if introduced |
| Anonymous / child accounts (post-MVP) | Separate suite: anonymous UID, owner-tied token, approval workflow—**do not** fold into Week 3 core |

---

## 4. Suggested harness progression

1. **Keep** mocktail unit tests on ports (`AuthRemoteDataSource`, future `*RemoteDataSource`).
2. **Add** Firebase Emulator Suite (Auth + Firestore + Storage) for integration/rules—do not hit production project from CI.
3. **Add** a small `integration_test/` or `test/emulator/` folder gated by `FIRESTORE_EMULATOR_HOST`.
4. **Manual device checklist** (two physical devices) remains the Week 2 leftover deliverable once bases/chat are cloud-backed.

---

## 5. Exit criteria for “cloud persistence test-complete”

- [ ] Feature unit tests still pass with `remote` wired (local-only path remains covered).
- [ ] Rules tests prove non-member deny for bases (and chat).
- [ ] Emulator two-user join + chat round-trip green in CI or documented nightly.
- [ ] Two real devices: same base, chat over network, nicknames from Firestore profiles.
- [ ] Legacy local-only assumptions removed or clearly marked obsolete in docs/tests.
- [ ] Scale-oriented Auth tests (rate-limit mapping, controller races) tracked or done.

---

## 6. Related Week 2 deferrals (context)

- Membership Firestore rules and true two-device shared base/chat.
- Invite expiry / maxUses enforcement on the **live** features join path.
- Auth scale coverage and legacy `base_sidebar` test rewiring.
- Post-MVP anonymous/child accounts (nickname + owner verification)—separate backlog.

---

*Generated for MoonBase Week 2 close-out on `feature/firebase-integration`. Update this file when the first Firestore-backed repository lands.*
