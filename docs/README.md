# MoonBase Skeleton — Documentation Index

This folder contains architecture, process, and reference docs. Phase 2 archives live under [`phase2/`](phase2/).

---

## Current

| Document | Description |
|----------|-------------|
| [PHASE3_DOD_ACTION_LIST.md](PHASE3_DOD_ACTION_LIST.md) | Phase 3 DoD checklist (media in chat, stories, posts, reactions). **In progress** — Foundation + Slice A device-verified on Android (2026-06-22). |
| [PHASE3_POSTS_STORIES_REACTIONS_BLUEPRINT.md](PHASE3_POSTS_STORIES_REACTIONS_BLUEPRINT.md) | Phase 3 architectural blueprint (cloud-ready contracts). |
| [DEVELOPMENT_SETUP.md](DEVELOPMENT_SETUP.md) | Onboarding: FVM, IDE, Firebase foundation, commits. |
| [DEV_GUIDE.md](DEV_GUIDE.md) | Git workflow, FVM, Flutter basics, testing strategy. |
| [FIRESTORE_SCHEMA.md](FIRESTORE_SCHEMA.md) | Week 3 Firestore document shape (`schemaVersion: 1`), Decisions & deferred, and rules summary. Rules emulator suite: [`../firestore/tests/`](../firestore/tests/). |
| [RESILIENCE_DECISIONS.md](RESILIENCE_DECISIONS.md) | Hang measurements, red herrings, network posture. Figures from instrumentation removed 2026-08-13. |
| [WEEK3_PR_SUMMARY.md](WEEK3_PR_SUMMARY.md) | Week 3 PR summary: what shipped, critical locked notes, test plan. |
| [FIRESTORE_UPDATE_TRIGGERS.md](FIRESTORE_UPDATE_TRIGGERS.md) | Scale-time reference: what’s parked in rules/tests and the precise trigger that forces a change. |
| [CLOUD_FIRESTORE_TEST_EXPANSION.md](CLOUD_FIRESTORE_TEST_EXPANSION.md) | Where tests must expand when profiles/bases/chat move to Firestore (Week 3+). |
| [git_alias_cheat_sheet.md](git_alias_cheat_sheet.md) | Optional git shortcuts. |
| [DIAG_HANG_REVERT_PLAN.md](DIAG_HANG_REVERT_PLAN.md) | **Executed 2026-08-13.** Historical strip procedure. Survivors and naming convention: see the header and [`RESILIENCE_DECISIONS.md`](RESILIENCE_DECISIONS.md). |

---

## Follow-ups (not this PR)

Git-workflow docs, deferred so they do not block Phase 1 merge:

1. Commit `GIT_HYGIENE_GUIDE.md` under `docs/` as the git-workflow canonical (own small `docs:` PR).
2. Uncomment `.vscode/` in `.gitignore` so the per-contributor untracked convention is real (hygiene § 8).
3. Resolve the branch-prefix conflict between [`DEVELOPMENT_SETUP.md`](DEVELOPMENT_SETUP.md) § 4.1 and [`DEV_GUIDE.md`](DEV_GUIDE.md), then rewrite `DEVELOPMENT_SETUP.md` § 4 as a pointer at the hygiene guide.

`chore/dart-format` rebases onto `main` **after** this branch merges, then re-runs `fvm dart format .`. Do not merge the format sweep first.

---

## Reference (still pertinent)

| Document | Description |
|----------|-------------|
| [MODEL_ARCHITECTURE.md](MODEL_ARCHITECTURE.md) | Data/domain model overview. Domain entities live under `lib/features/<feature>/domain/entities/`. |
| [PROFILE_PERSISTENCE.md](PROFILE_PERSISTENCE.md) | Profile storage and auth flow (UUID, nickname, theme). Still relevant to the auth feature. |
| [README-ios.md](README-ios.md) | iOS-specific notes. |
| [phase2/REFACTOR_ARCHITECTURE.md](phase2/REFACTOR_ARCHITECTURE.md) | 3-layer Clean Architecture overview (Phase 2 archive; still the primary architecture reference). |

---

## Phase 2 archive (`phase2/`)

Completed Phase 2 checklists and guides, kept for history.

| Document | Description |
|----------|-------------|
| [phase2/PHASE2_DOD_ACTION_LIST.md](phase2/PHASE2_DOD_ACTION_LIST.md) | Phase 2 DoD checklist (**completed**). |
| [phase2/REFACTOR_ARCHITECTURE.md](phase2/REFACTOR_ARCHITECTURE.md) | 3-layer architecture write-up. |
| [phase2/test_chat.md](phase2/test_chat.md) | Manual chat test guide (legacy flows). |
| [phase2/test_base_management.md](phase2/test_base_management.md) | Manual base management test guide (legacy flows). |
| [phase2/base_sidebar_test_suite.md](phase2/base_sidebar_test_suite.md) | Legacy BaseSidebar test reference. |

---

## Deprecated (legacy implementation)

These describe the **legacy** provider/repository/screen layer. For current behavior, see [phase2/REFACTOR_ARCHITECTURE.md](phase2/REFACTOR_ARCHITECTURE.md) and `lib/features/`.

| Document | Description |
|----------|-------------|
| [ARCHITECTURE_ANALYSIS.md](ARCHITECTURE_ANALYSIS.md) | Pre-refactor analysis; superseded by the current architecture. |
| [dependency_graph.md](dependency_graph.md) | Legacy provider dependency graph. |
| [test_invites.md](test_invites.md) | Manual invites test guide; legacy flows. |

---

*Last updated for Week 3 schema design: see [FIRESTORE_SCHEMA.md](FIRESTORE_SCHEMA.md) and root `firestore.rules`. Auth live; product data still local until repository swaps.*
