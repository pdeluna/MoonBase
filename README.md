# MoonBase Skeleton

A Flutter app for closed-circle chat and content sharing. Built on a **3-layer Clean Architecture** (`lib/features/`) with Firebase Auth live for accounts, while bases/chat/profiles remain local until Week 3+ cloud persistence.

## Table of Contents

- [Current Status](#current-status)
- [Features](#features)
- [Firebase](#firebase)
- [Architecture](#architecture)
- [Getting Started](#getting-started)
- [Testing](#testing)
- [Data storage](#data-storage)
- [Project Structure](#project-structure)
- [Documentation](#documentation)
- [Roadmap](#roadmap)

## Current Status

| Layer | Status |
|-------|--------|
| Phase 2 — 3-layer architecture | **Complete** |
| Phase 3 — media / chat attachments | **In progress** (Foundation + Slice A device-verified on Android) |
| Phase 4 — Firebase | **Auth + Firestore product data live** (profiles, bases, chat); Storage upload + resolve live |
| Hang Phase 1 (R2–R5) | **Code-complete 2026-08-13** — see [`docs/RESILIENCE_DECISIONS.md`](docs/RESILIENCE_DECISIONS.md) |

Active code lives under `lib/features/` and `lib/core/`. Pre-refactor code is quarantined under `lib/legacy/` (and `test/legacy/`) for reference until screens are fully rebuilt.

## Features

### Auth (Firebase)

- Email/password **sign-up / sign-in / sign-out** via Firebase Auth
- **Nickname** collected on sign-up (stored as Firebase `displayName` + local profile); used for chat labels
- Session mirrored locally (`AuthRepositoryImpl` + SharedPreferences); Firebase Auth is source of truth for identity
- Sign-up / login UI under `lib/legacy/screens/` wired to `AuthController`

### Bases, invites, chat, profile (Firestore)

- **Bases**: create/join via invites, sidebar rename/delete, last-accessed base (device-local prefs), clear selection on logout
- **Invites**: create, list, redeem (cloud; `inviteCodes/{code}` lookup)
- **Chat**: `ChatController` single source of truth; text + cloud image attachments; cache-vs-live freshness banner
- **Profile**: view current user; `themeMode` on the profile doc is not yet live theming (prefs still)
- **Cross-platform**: Android, iOS, Web, Windows, macOS, Linux

### Media (Phase 3)

- Shared `media` feature: pick/capture, local file storage, tiles/preview/picker sheet
- Chat composer attach flow (images + short video)

### Planned

- Stories, posts, reactions (Phase 3 slices B/C)
- Live streaming, push, analytics, anonymous/child accounts (post-MVP backlog)

## Firebase

### What is wired today

| Product | Status |
|---------|--------|
| **Firebase Core** | Initialized at startup in `lib/main.dart` (`Firebase.initializeApp` + `DefaultFirebaseOptions`). Android BoM **34.17.0** |
| **Firebase Auth** | Live — email/password; nickname via `updateDisplayName`. Native **24.2.0** (dual-stack Wi-Fi timeout fix) |
| **Cloud Firestore** | Live — `users`, `bases` / members / invites, `messages`. Native **26.5.0** (no equivalent dual-stack fix) |
| **Firebase Storage** | Live — chat image upload + `getDownloadURL`. Native **22.0.1** (no equivalent dual-stack fix) |

Config (FlutterFire-generated, checked in):

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `firebase.json`

Android `minSdk` is **23+** (required by `firebase_auth`).

Regenerate against your own project with `flutterfire configure`. These files hold client config, not server secrets—harden with Security Rules and API-key restrictions.

### What is still local

Last-accessed base is device-local SharedPreferences (keyed by uid). Picker staging uses local files before cloud upload. Stories / posts / reactions are not in this build.

See [docs/FIRESTORE_SCHEMA.md](docs/FIRESTORE_SCHEMA.md) and [docs/RESILIENCE_DECISIONS.md](docs/RESILIENCE_DECISIONS.md).

## Architecture

### Current: 3-layer (feature-based)

```
lib/
├── core/                     # either, failure, ids, validators, Firebase smoke probe, …
├── features/
│   ├── auth/                 # Firebase Auth remote + local session mirror
│   ├── bases/                # bases, invites (Firestore)
│   ├── chat/                 # controller, screen, composer, bubbles
│   ├── media/                # picker + local staging + cloud Storage
│   ├── profile/
│   └── theme/
├── legacy/                   # quarantined pre-3-layer screens/services/providers
├── firebase_options.dart
├── router.dart
└── main.dart                 # Firebase.initializeApp + ProviderScope wiring
```

Each feature: **domain** (entities, repos, use cases) → **data** (impls, models, data sources) → **presentation** (controllers, providers, UI).

See [docs/phase2/REFACTOR_ARCHITECTURE.md](docs/phase2/REFACTOR_ARCHITECTURE.md).

## Getting Started

### Prerequisites

- Flutter SDK (≥3.27.0) — prefer **FVM** per [docs/DEVELOPMENT_SETUP.md](docs/DEVELOPMENT_SETUP.md)
- Dart SDK (≥3.6.0)
- Android `minSdk` 23+

### Installation

```bash
cd MoonBase   # or your clone path
fvm flutter pub get   # or: flutter pub get
fvm flutter run -d windows   # or an authorized Android device
```

### Debug network harness

Deterministic Firestore/Storage degradation for reproducing Android gRPC /
transport hangs. **Physical Android device only** — Windows desktop uses a
different Firestore implementation, and emulator networking is NATed through
the host (neither matches real Wi-Fi association failure shapes).

Flags are compile-time (`--dart-define`) and hard-disabled outside debug
(`kDebugMode`). They are **mutually exclusive**.

```powershell
# List devices; use a physical Android id (not windows, not an emulator).
fvm flutter devices

# Offline-with-cache (Firestore disableNetwork — local cache still serves reads)
fvm flutter run -d <device-id> --dart-define=MOONBASE_FORCE_OFFLINE=true

# Connect hang (TEST-NET-1 192.0.2.1:443 — Firestore Settings.host + Storage
# useStorageEmulator; packets dropped, not refused)
fvm flutter run -d <device-id> --dart-define=MOONBASE_BLACKHOLE=true
```

When armed, a top-of-screen banner shows the active mode. Implementation:
`lib/core/debug/firebase_debug_harness.dart` (bootstrap applies it from
`lib/main.dart` — single `Settings` assignment site).

### Quick start

1. **Create account** — nickname (chat label) → email → password
2. **Create a base** from home / sidebar
3. **Chat** — select a base; send text or attach media
4. **Invites** — create a code; on the **same device**, sign in as a second email account and join
5. (Debug) Profile → **Firestore smoke test** to verify Firestore connectivity

Cross-device join/chat requires Week 3+ cloud persistence.

## Testing

```bash
# Recommended merge gate (current build)
flutter test test/features test/core

# Auth / nickname coverage
flutter test test/features/auth/

# Full suite (includes legacy; some legacy failures expected)
flutter test
```

| Suite | Expectation |
|-------|-------------|
| `test/features/**`, `test/core/**` | Should stay green for PRs |
| `test/legacy/**` | Quarantined; known failures (e.g. sidebar missing `authRepositoryProvider` override) |

Cloud/Firestore expansion checklist: [docs/CLOUD_FIRESTORE_TEST_EXPANSION.md](docs/CLOUD_FIRESTORE_TEST_EXPANSION.md).

### Manual smoke (Auth + local data)

- Sign up with nickname; confirm chat labels use nickname (not raw email)
- Second email account joins base via invite (same device); chat authors correct across logout
- Dark mode persists per session/profile expectations
- Media attach + permission denial snackbar (Android device notes in Phase 3 docs)

## Data storage

| Data | Backend today |
|------|----------------|
| Auth identity (`uid`, email, `displayName`) | **Firebase Auth** |
| Profiles, bases, members, invites, chat messages | **Cloud Firestore** (`schemaVersion: 1`) |
| Session mirror / last-accessed base | **SharedPreferences** |
| Chat image bytes | **Firebase Storage** (picker staging is local files) |

## Development

### Adding features (3-layer)

1. Domain entities / repository interfaces / use cases under `lib/features/<feature>/domain/`
2. Data sources + repository impls under `data/`
3. Controllers / providers / UI under `presentation/`
4. Tests under `test/features/<feature>/`

### Code quality

```bash
flutter analyze
dart format lib/
flutter test test/features test/core
```

### Key dependencies

- `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage` — Firebase
- `flutter_riverpod` — state
- `shared_preferences` — local product data
- `go_router` — navigation
- `image_picker`, `video_player`, `path_provider`, … — Phase 3 media

## Project structure

```
lib/
├── core/
├── features/          # auth, bases, chat, media, profile, theme
├── legacy/            # deprecated flat layout (screens still used by router)
├── firebase_options.dart
├── main.dart
└── router.dart

test/
├── features/          # first-class tests
├── core/
└── legacy/            # quarantined
```

## Documentation

- **[docs/README.md](docs/README.md)** — doc index
- [DEVELOPMENT_SETUP.md](docs/DEVELOPMENT_SETUP.md) — FVM, IDE, commits, Firebase foundation notes
- [CLOUD_FIRESTORE_TEST_EXPANSION.md](docs/CLOUD_FIRESTORE_TEST_EXPANSION.md) — tests to add when cloud persistence lands
- [REFACTOR_ARCHITECTURE.md](docs/phase2/REFACTOR_ARCHITECTURE.md) — 3-layer architecture (Phase 2 archive)
- [DEV_GUIDE.md](docs/DEV_GUIDE.md) — Git / Flutter workflow
- [PHASE3_DOD_ACTION_LIST.md](docs/PHASE3_DOD_ACTION_LIST.md) — Phase 3 checklist
- [PHASE3_POSTS_STORIES_REACTIONS_BLUEPRINT.md](docs/PHASE3_POSTS_STORIES_REACTIONS_BLUEPRINT.md) — Phase 3/4 blueprint

## Roadmap

### Phase 1–2 — Complete

Legacy PoC → 3-layer refactor, feature modules, local persistence, chat architecture.

### Phase 3 — In progress

- Media foundation + chat media (Slice A) — complete / Android-verified
- Stories (Slice B), posts + reactions (Slice C) — planned / in progress on feature branches

### Phase 4 / Week 3+ — Firebase product data

- **Done:** Core init; **Auth** email/password + nickname; Firestore profiles / bases / chat; Storage upload + resolve; hang Phase 1 (R2–R5) 2026-08-13
- **Parked:** Firestore/Storage dual-stack SDK fix (Auth-only today); first-sign-in create-or-return write unbounded — [docs/FIRESTORE_UPDATE_TRIGGERS.md](docs/FIRESTORE_UPDATE_TRIGGERS.md)
- Later: Storage-backed media, live streaming, push, analytics
- Post-MVP backlog: anonymous/child accounts (owner-tied verification)

## License

This project is licensed under the MIT License.

---

**MoonBase** — Closed-circle communication with real Auth now, cloud sync next.
