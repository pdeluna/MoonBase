# MoonBase Skeleton - Refactored Architecture

## Overview

This document outlines the MoonBase Skeleton 3-layer architecture. **Phase 2 is complete**: data persistence, UI/widget wiring, and session management are in place; the app runs on this architecture with unit test validation at approximately 80%.

## Architecture Overview

The refactored codebase follows Clean Architecture principles with a clear separation between:

- **Domain Layer** - Business logic and entities
- **Data Layer** - Repository implementations and data sources  
- **Presentation Layer** - Controllers and UI state management

## Directory Structure

```
lib/
├── core/                           # Shared utilities and abstractions
│   ├── either.dart                 # Result type for error handling
│   ├── failure.dart                # Failure types (Network, Cache, Validation, Unknown)
│   ├── ids.dart                    # Type-safe ID wrappers (UserId, BaseId, etc.)
│   ├── usecase.dart                # Base use case interface
│   ├── error_mapper.dart           # Error handling utilities
│   └── validators.dart             # Input validation functions
│
├── features/                       # Feature-based modules
│   ├── auth/                       # Authentication feature
│   │   ├── data/
│   │   │   └── repositories/
│   │   │       └── auth_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   ├── repositories/
│   │   │   │   └── auth_repository.dart
│   │   │   └── usecases/
│   │   └── presentation/
│   │       └── controllers/
│   │           └── auth_controller.dart
│   │
│   ├── bases/                      # Base management feature
│   │   ├── data/
│   │   │   └── repositories/
│   │   │       └── base_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── base.dart
│   │   │   ├── repositories/
│   │   │   │   └── base_repository.dart
│   │   │   └── usecases/
│   │   │       ├── create_base.dart
│   │   │       ├── delete_base.dart
│   │   │       ├── generate_invite_code.dart
│   │   │       ├── join_base.dart
│   │   │       ├── leave_base.dart
│   │   │       ├── list_bases.dart
│   │   │       └── rename_base.dart
│   │   └── presentation/
│   │       └── controllers/
│   │           └── base_controller.dart
│   │
│   ├── chat/                       # Chat feature
│   │   ├── data/
│   │   │   └── repositories/
│   │   │       └── chat_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   ├── repositories/
│   │   │   │   └── chat_repository.dart
│   │   │   └── usecases/
│   │   │       └── send_message.dart
│   │   └── presentation/
│   │       └── controllers/
│   │           └── chat_controller.dart
│   │
│   └── profile/                    # Profile management feature
│       ├── data/
│       │   ├── datasources/
│       │   │   ├── profile_local_data_source.dart
│       │   │   └── profile_remote_data_source.dart
│       │   ├── models/
│       │   │   └── profile_model.dart
│       │   └── repositories/
│       │       └── profile_repository_impl.dart
│       ├── domain/
│       │   ├── entities/
│       │   │   └── profile.dart
│       │   ├── repositories/
│       │   │   └── profile_repository.dart
│       │   └── usecases/
│       │       └── update_profile.dart
│       └── presentation/
│           └── controllers/
│               └── profile_controller.dart
│
├── models/                         # Legacy models (to be migrated)
├── providers/                      # Legacy providers (to be migrated)
├── screens/                        # Legacy screens (to be migrated)
├── services/                       # Legacy services (to be migrated)
├── utils/                          # Legacy utilities (to be migrated)
├── widgets/                        # Legacy widgets (to be migrated)
├── router.dart                     # Navigation routing
└── main.dart                       # Application entry point

test/
├── features/                       # Feature-based test organization
│   ├── auth/
│   ├── bases/
│   │   └── domain/
│   │       └── usecases/
│   │           └── join_base_test.dart
│   ├── chat/
│   └── profile/
│       └── domain/
│           └── usecases/
│               └── update_profile_test.dart
│
├── providers/                      # Legacy provider tests
├── screens/                        # Legacy screen tests
├── services/                       # Legacy service tests
├── widgets/                        # Legacy widget tests
└── test_utils/                     # Shared test utilities (planned)
    └── mocks/                      # Mock implementations (planned)
```

## Core Components

### 1. Core Layer (`/core`)

**Purpose**: Shared utilities and abstractions used across all features.

**Key Components**:
- **`either.dart`**: Result type for functional error handling
- **`failure.dart`**: Standardized failure types (Network, Cache, Validation, Unknown)
- **`ids.dart`**: Type-safe ID wrappers preventing ID confusion
- **`usecase.dart`**: Base interface for all use cases
- **`validators.dart`**: Input validation functions for user-facing validation
- **`error_mapper.dart`**: Error handling and mapping utilities

### 2. Feature Modules (`/features`)

Each feature follows the same internal structure:

#### Domain Layer
- **Entities**: Core business objects
- **Repositories**: Abstract interfaces defining data contracts
- **Use Cases**: Business logic implementation

#### Data Layer  
- **Repository Implementations**: Concrete implementations of domain repositories
- **Data Sources**: Local and remote data access (where applicable)
- **Models**: Data transfer objects and serialization

#### Presentation Layer
- **Controllers**: State management and business logic coordination

### 3. Test Structure (`/test`)

**Current State**: 
- **`/test/features`**: New feature-based test organization mirroring the feature structure
- **`/test/providers`**: Legacy provider tests (to be migrated)
- **`/test/screens`**: Legacy screen tests (to be migrated)
- **`/test/services`**: Legacy service tests (to be migrated)
- **`/test/widgets`**: Legacy widget tests (to be migrated)

**Planned**:
- **`/test/test_utils`**: Shared test utilities and mock implementations
- **`/test/test_utils/mocks`**: Centralized mock classes for repositories and data sources

## Key Architectural Decisions

### 1. Use Case Pattern
All business logic is encapsulated in use cases that:
- Accept parameters through dedicated parameter classes
- Return `Either<Failure, Success>` for error handling
- Include user-facing validation for crisp UX
- Are easily testable in isolation

### 2. Repository Pattern
- Domain layer defines abstract repository interfaces
- Data layer provides concrete implementations
- Enables easy testing with mock implementations
- Supports multiple data sources (local, remote)

### 3. Error Handling
- Functional approach using `Either<Failure, Success>`
- Standardized failure types for consistent error handling
- User-facing validation in use cases for immediate feedback

### 4. Type Safety
- Custom ID types prevent ID confusion
- Strong typing throughout the application
- Compile-time safety for critical operations

## Current Implementation Status

### ✅ Completed (Phase 2)
- Core architecture and abstractions
- Feature-based directory structure (auth, bases, chat, profile, theme)
- Use case implementations with validation
- Repository interfaces and implementations with persistence
- UI/widget wiring; controllers drive screens and widgets
- Session management and authentication flow
- Chat: single source of truth, AsyncValue.when, dumb tiles, scroll-to-latest, nicknames/colors
- Test structure under `test/features/`; unit test validation ~80%
- Input validation system

### Legacy (deprecated)
- `lib/providers/`, `lib/services/`, `lib/screens/`, `lib/models/` and related tests are deprecated and kept for reference only.

### Possible next steps
- Increase test coverage and add mocks where needed
- Remove or further isolate legacy code
- Phase 3: media, posts, content moderation; Phase 4: streaming, reactions, analytics

## Benefits of This Architecture

1. **Testability**: Each layer can be tested in isolation
2. **Maintainability**: Clear separation of concerns
3. **Scalability**: Easy to add new features following the same pattern
4. **Flexibility**: Can swap implementations without affecting business logic
5. **Type Safety**: Compile-time guarantees for critical operations
6. **Error Handling**: Consistent error handling across the application

---

*This architecture provides a solid foundation for building a maintainable, testable, and scalable Flutter application while preserving the flexibility to implement the remaining components as needed.*

