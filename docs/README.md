# MoonBase Skeleton — Documentation Index

This folder contains architecture, process, and reference docs. Documents are grouped as **current** (Phase 2 / 3-layer architecture), **reference** (still pertinent), or **deprecated** (legacy implementation; kept for context only).

---

## Current (Phase 2 / 3-layer architecture)

| Document | Description |
|----------|-------------|
| [REFACTOR_ARCHITECTURE.md](REFACTOR_ARCHITECTURE.md) | Primary reference for the 3-layer Clean Architecture, feature layout, and implementation status. |
| [PHASE2_DOD_ACTION_LIST.md](PHASE2_DOD_ACTION_LIST.md) | Phase 2 DoD checklist. **Completed**; retained as an archive. |
| [DEV_GUIDE.md](DEV_GUIDE.md) | Git workflow, FVM, Flutter basics, testing strategy. |
| [git_alias_cheat_sheet.md](git_alias_cheat_sheet.md) | Optional git shortcuts. |

---

## Reference (still pertinent)

| Document | Description |
|----------|-------------|
| [MODEL_ARCHITECTURE.md](MODEL_ARCHITECTURE.md) | Data/domain model overview. Domain entities live under `lib/features/<feature>/domain/entities/`; some names may align with legacy models. |
| [PROFILE_PERSISTENCE.md](PROFILE_PERSISTENCE.md) | Profile storage and auth flow (UUID, nickname, theme). Still relevant to the auth feature. |
| [README-ios.md](README-ios.md) | iOS-specific notes. |

---

## Deprecated (legacy implementation)

These describe the **legacy** provider/repository/screen layer. For current behavior, see [REFACTOR_ARCHITECTURE.md](REFACTOR_ARCHITECTURE.md) and the code under `lib/features/`.

| Document | Description |
|----------|-------------|
| [ARCHITECTURE_ANALYSIS.md](ARCHITECTURE_ANALYSIS.md) | Pre-refactor analysis and recommendations; superseded by the current architecture. |
| [dependency_graph.md](dependency_graph.md) | Legacy provider dependency graph (e.g. `sessionProvider`, `chatMessagesProvider`). |
| [test_chat.md](test_chat.md) | Manual chat test guide; legacy flows. |
| [test_base_management.md](test_base_management.md) | Manual base management test guide; legacy flows. |
| [test_invites.md](test_invites.md) | Manual invites test guide; legacy flows. |
| [base_sidebar_test_suite.md](base_sidebar_test_suite.md) | Sidebar test reference; may target legacy sidebar. |

---

*Last updated for Phase 2 completion and docs consolidation.*
