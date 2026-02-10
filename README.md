# MoonBase Skeleton

A minimal Flutter skeleton for MoonBase (closed-circle streaming/chat). Pure navigation, no Firebase.

## Table of Contents

- [Current Status](#-current-status-phase-2-complete)
- [Features](#-features)
- [Architecture](#-architecture)
- [Getting Started](#-getting-started)
- [Testing](#-testing)
- [Project Structure](#-project-structure)
- [Documentation](#-documentation)
- [Roadmap](#-roadmap)

## Current Status: Phase 2 Complete

Phase 2 MVP is complete. The app runs on a **3-layer Clean Architecture** (domain / data / presentation) with feature-based modules. Data persistence, UI wiring, and session management are in place. Unit test validation is approximately **80% complete**. Legacy code under `lib/providers/`, `lib/services/`, `lib/screens/`, and `lib/models/` is **deprecated** and retained only for reference; the active implementation lives under `lib/features/` and `lib/core/`.

## Features

### Current (Phase 2 — 3-layer architecture)

- **Auth**: Profile-based sign-in/sign-out, current user and session
- **Bases**: Full CRUD, create/join via invites, sidebar rename/delete, last-accessed base per user, clear selection on logout
- **Invites**: Create, list, and redeem invite codes from home
- **Chat**: Single source of truth (`ChatController`); load on base change and initial load; list from `AsyncValue<List<Message>>`; dumb `MessageBubble` and `MessageComposer` (no provider reads); nicknames and colored names via `memberPresentationProvider` at list level; scroll-to-latest; unified loading/empty/error and retry at screen level
- **Profile**: View and update profile
- **Cross-platform**: Android, iOS, Web, Windows, macOS, Linux

### Legacy (deprecated)

- Old provider layer: `basesProvider`, `sessionProvider`, `invitesProvider`, `chatMessagesProvider`, `chatStreamProvider`, `chatActionsProvider`
- Old repositories: `SpBasesRepository`, `SpProfileRepository`, `SpInvitesRepository`, `SpChatRepository`
- Legacy screens under `lib/screens/` (replaced by feature presentation layers)

### Planned

- Live streaming, media system, reactions, analytics (see Roadmap)

## Chat Functionality

The chat system uses the Phase 2 architecture:

### Core behavior

- **Single source of truth**: `ChatController` holds `AsyncValue<List<Message>>`; `load(baseId)` and stream ticks update state; `send()` persists and the stream drives UI refresh
- **Real-time list**: Messages rendered from controller state only; no per-message providers in the list
- **Dumb UI**: `MessageBubble` and `MessageComposer` receive data via props; no provider reads inside tiles or composer
- **Presentation**: Nicknames and colors from `memberPresentationProvider` at list level, passed into each bubble
- **States**: One place for loading, empty, error, and retry via `AsyncValue.when` at chat screen level
- **Scroll-to-latest**: List uses `reverse: true` and a scroll controller to jump to bottom when new messages appear
- **Persistence**: SharedPreferences via `ChatRepositoryImpl` / `ChatSharedPrefsDataSource`; base-isolated chats

### Technical

- **Repository**: `ChatRepository` (domain) implemented by `ChatRepositoryImpl` (data)
- **Use cases**: `ListMessages`, `SendMessage`, `StreamMessages`
- **State**: Riverpod `chatControllerProvider`, `chatScreenVmProvider`; sidebar/base selection via `effectiveSelectedBaseProvider`

## Architecture

### Current: 3-layer (feature-based)

```
lib/
├── core/                     # Shared utilities and abstractions
│   ├── either.dart           # Result type for error handling
│   ├── failure.dart          # Failure types (Network, Cache, Validation, Unknown)
│   ├── ids.dart              # Type-safe ID wrappers (UserId, BaseId, MessageId, etc.)
│   ├── usecase.dart          # Base use case interface
│   ├── validators.dart       # Input validation
│   └── error_mapper.dart     # Error handling utilities
│
├── features/                 # Feature modules (domain / data / presentation)
│   ├── auth/                 # Authentication
│   ├── bases/                # Base CRUD, invites, sidebar
│   ├── chat/                 # Chat controller, screen, list, composer
│   ├── profile/              # Profile management
│   └── theme/                # Theme providers
│
├── providers/                # Legacy (deprecated)
├── services/                 # Legacy (deprecated)
├── screens/                  # Legacy (deprecated)
├── models/                   # Legacy (deprecated)
├── router.dart
└── main.dart
```

Each feature follows:

- **Domain**: entities, repository interfaces, use cases
- **Data**: repository implementations, data sources, models
- **Presentation**: controllers, providers, screens, widgets

### Legacy (deprecated — reference only)

```
Repository Layer: SpBasesRepository, SpProfileRepository, SpInvitesRepository, SpChatRepository
Provider Layer:   basesProvider, sessionProvider, invitesProvider, chatMessagesProvider, etc.
UI Layer:         LoginScreen, HomeScreen, ChatScreen (legacy paths under lib/screens/)
```

See [docs/REFACTOR_ARCHITECTURE.md](docs/REFACTOR_ARCHITECTURE.md) for the current architecture.

## Getting Started

### Prerequisites

- Flutter SDK (>=3.22.0)
- Dart SDK (>=3.3.0)

### Installation

1. Clone the repository
2. Navigate to the project directory (`moonbase_skeleton`)
3. Run `flutter pub get`
4. Run `flutter run`

### Quick Start

1. **Sign in**: Enter a nickname to create a profile
2. **Create a base**: Use base creation from home
3. **Chat**: Select a base and open the Chat tab; send messages
4. **Invites**: Create invite codes and share; join bases via code

## Testing

### Running tests

```bash
# Full test suite
flutter test

# Chat feature only
flutter test test/features/chat/

# Other feature tests
flutter test test/features/auth/
flutter test test/features/bases/
flutter test test/features/profile/
```

### Coverage

- **Feature tests**: Under `test/features/` (auth, bases, chat, profile) — repositories, controllers, use cases
- **Unit test validation**: ~80% complete for Phase 2 scope
- **Legacy tests**: `test/providers/`, `test/services/`, `test/screens/`, `test/widgets/` (legacy; may be retired)

### Manual smoke (Phase 2 sign-off)

- Bases: create, join via invite, sidebar rename/delete
- Invites: create, list, redeem
- Chat: send message, switch base, see loading/empty/error and retry
- Profile: view and update
- Error/empty states and no regressions

## Data storage

- **SharedPreferences**: Local storage for messages, profiles, bases, invites
- **Stream-based updates**: Chat list updates from message stream
- **Base isolation**: Each base has its own chat history

## Development

### Adding new features (3-layer)

1. Add or extend entities and repository interfaces in `lib/features/<feature>/domain/`
2. Implement use cases in `lib/features/<feature>/domain/usecases/`
3. Implement repositories and data sources in `lib/features/<feature>/data/`
4. Add controllers and providers in `lib/features/<feature>/presentation/`
5. Add tests under `test/features/<feature>/`

### Code quality

```bash
flutter analyze
flutter format lib/
flutter test
```

### Dependencies

- `flutter_riverpod`: State management
- `shared_preferences`: Local storage
- `uuid`: Unique ID generation
- `go_router`: Navigation

## Project structure

### Current (feature-based)

```
lib/
├── core/                           # Shared utilities and abstractions
├── features/
│   ├── auth/                        # domain, data, presentation
│   ├── bases/                       # domain, data, presentation (incl. invites, sidebar)
│   ├── chat/                        # domain, data, presentation (controller, screen, widgets)
│   ├── profile/
│   └── theme/
├── providers/                       # Legacy (deprecated)
├── services/                        # Legacy (deprecated)
├── screens/                         # Legacy (deprecated)
├── models/                          # Legacy (deprecated)
├── router.dart
└── main.dart

test/
├── features/                        # auth, bases, chat, profile
├── providers/                       # Legacy
├── screens/                         # Legacy
├── services/                        # Legacy
└── widgets/                         # Legacy
```

See [docs/REFACTOR_ARCHITECTURE.md](docs/REFACTOR_ARCHITECTURE.md) for detailed structure.

## Documentation

- **[docs/README.md](docs/README.md)** — Index of all documentation (current vs deprecated)
- [REFACTOR_ARCHITECTURE.md](docs/REFACTOR_ARCHITECTURE.md) — 3-layer architecture (current)
- [PHASE2_DOD_ACTION_LIST.md](docs/PHASE2_DOD_ACTION_LIST.md) — Phase 2 DoD (completed; archive)
- [DEV_GUIDE.md](docs/DEV_GUIDE.md) — Git, FVM, Flutter workflow
- [MODEL_ARCHITECTURE.md](docs/MODEL_ARCHITECTURE.md) — Data/domain model reference
- [PROFILE_PERSISTENCE.md](docs/PROFILE_PERSISTENCE.md) — Profile storage and auth flow
- [git_alias_cheat_sheet.md](docs/git_alias_cheat_sheet.md) — Optional git shortcuts

## Roadmap

### Phase 1: Legacy proof of concept — Complete

- User authentication, base management, invites, real-time chat, message persistence

### Phase 2: Architecture refactor — Complete

- 3-layer Clean Architecture, use cases, repository pattern, type-safe IDs
- Feature-based layout, data persistence, UI/widget wiring, session management
- Chat single source of truth, AsyncValue.when, dumb tiles, scroll-to-latest, nicknames/colors
- Unit test validation ~80%

### Phase 3: Content features — Planned

- Media upload and display, posts and stories, content moderation

### Phase 4: Advanced features — Planned

- Live streaming, voice messages, file sharing, reactions, analytics

## License

This project is licensed under the MIT License.

---

**MoonBase Skeleton** — A minimal Flutter app for closed-circle communication and content sharing.
