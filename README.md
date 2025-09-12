# MoonBase Skeleton

A minimal Flutter skeleton for MoonBase (closed-circle streaming/chat). Pure navigation, no Firebase.

## 🚀 **Current Status: Refactoring in Progress**

MoonBase Skeleton is currently undergoing a major architectural refactor to implement Clean Architecture principles. The **legacy build** contains fully functional proof-of-concept features including chat, base management, and user authentication. The **refactor branch** is implementing a new 3-layer architecture with proper separation of concerns.

## ✨ **Features**

### 🏗️ **LEGACY BUILD (Proof of Concept)**
- **Base Management**: Create, read, update bases with full CRUD operations
- **User Authentication**: Profile-based authentication with persistence
- **Invitation System**: Complete invite creation, redemption, and tracking
- **Real-time Chat**: Full messaging system with persistence and base isolation
- **Base Membership**: Role-based access control (owner, admin, member)
- **Cross-platform**: Works on Android, iOS, Web, Windows, macOS, and Linux

### 🚧 **REFACTOR BRANCH (In Progress)**
- **Clean Architecture**: 3-layer architecture with proper separation of concerns
- **Use Case Pattern**: Business logic encapsulated in testable use cases
- **Repository Pattern**: Abstract interfaces with concrete implementations
- **Type Safety**: Custom ID types and functional error handling
- **Input Validation**: User-facing validation for crisp UX
- **Test Structure**: Feature-based test organization

### 📋 **PLANNED**
- **Data Persistence**: Actual storage implementation
- **UI/Widget Wiring**: Connecting controllers to UI components
- **Session Management**: User authentication and session handling
- **Live Streaming**: Session management and streaming functionality
- **Media System**: File uploads and media handling
- **Reactions System**: Like, heart, etc. on posts/messages

## 💬 **Chat Functionality**

The app includes a complete chat system with the following features:

### Core Features
- **Real-time messaging**: Messages appear instantly using streams
- **Message persistence**: All messages are stored locally using SharedPreferences
- **Message types**: Support for text, media, and system messages
- **Message actions**: Edit and delete messages (soft delete)
- **User identification**: Messages show sender information
- **Timestamps**: Messages display creation and edit times
- **Base-specific chats**: Each base has its own isolated chat room
- **Base consistency**: Messages are properly isolated by base
- **User persistence**: Chat history persists across app restarts

### Technical Implementation
- **Repository Pattern**: `SpChatRepository` handles data persistence
- **State Management**: Riverpod providers manage chat state
- **Streaming**: Real-time updates using Dart streams
- **Error Handling**: Comprehensive error handling and user feedback

## 🏗️ **Architecture**

### 🏗️ **Legacy Architecture**
```
Repository Layer:
├── SpBasesRepository     - Base CRUD operations
├── SpProfileRepository   - User authentication & profiles
├── SpInvitesRepository   - Invitation management
└── SpChatRepository      - Chat message operations

Provider Layer:
├── basesProvider         - Base state management
├── sessionProvider       - User session management
├── invitesProvider       - Invite state management
├── chatMessagesProvider  - Message state (per base)
├── chatStreamProvider    - Real-time updates (per base)
└── chatActionsProvider   - Message actions

UI Layer:
├── LoginScreen           - User authentication
├── HomeScreen            - Base selection & management
├── ChatScreen            - Real-time messaging
├── ProfileScreen         - User profile management
└── BasePickerScreen      - Base selection
```

### 🚧 **New Refactored Architecture**
```
Core Layer (/core):
├── either.dart           - Result type for error handling
├── failure.dart          - Standardized failure types
├── ids.dart              - Type-safe ID wrappers
├── usecase.dart          - Base use case interface
├── validators.dart       - Input validation functions
└── error_mapper.dart     - Error handling utilities

Feature Modules (/features):
├── auth/                 - Authentication feature
│   ├── domain/           - Entities, repositories, use cases
│   ├── data/             - Repository implementations
│   └── presentation/     - Controllers
├── bases/                - Base management feature
├── chat/                 - Chat feature
└── profile/              - Profile management feature
```

## 🚀 **Getting Started**

### Prerequisites
- Flutter SDK (>=3.22.0)
- Dart SDK (>=3.3.0)

### Installation
1. Clone the repository
2. Navigate to the project directory
3. Run `flutter pub get` to install dependencies
4. Run `flutter run` to start the app

### Quick Start
1. **Sign In**: Enter any nickname to create a profile
2. **Create a Base**: Navigate to base creation and create your first base
3. **Start Chatting**: Select your base to enter the chat screen
4. **Invite Friends**: Create invite codes to add others to your base

## 🧪 **Testing**

### Running Tests
```bash
# Run all tests
flutter test

# Run only chat-related tests
flutter test test/services/chat_repository_test.dart test/services/integration_test.dart

# Run specific test categories
flutter test test/services/chat_repository_test.dart
flutter test test/services/bases_repository_test.dart
flutter test test/services/invites_repository_test.dart
```

### Test Coverage
- **Unit Tests**: All repository methods (41 tests)
- **Integration Tests**: Complete user flows (3 tests)
- **Widget Tests**: Basic UI components

### Manual Testing Steps
1. **Start the app**: Run `flutter run`
2. **Sign in**: Use any nickname to create a profile
3. **Create a base**: Navigate to the base creation screen
4. **Access chat**: Select your base to enter the chat screen
5. **Send messages**: Type in the composer and tap send
6. **Test features**:
   - Send multiple messages
   - Verify real-time updates
   - Check message timestamps
   - Test message persistence (restart app)
   - Create invites and test multi-user chat

## 📊 **Data Storage**

- **SharedPreferences**: Local storage for messages and user data
- **JSON serialization**: Messages stored as JSON strings
- **Stream-based updates**: Real-time synchronization
- **Base isolation**: Each base has its own chat history
- **User persistence**: Profiles and sessions persist across restarts

## 🔧 **Development**

### Adding New Features
1. Update models in `lib/models/`
2. Add repository methods in `lib/services/`
3. Create providers in `lib/providers/`
4. Update UI in `lib/screens/`
5. Add tests in `test/`

### Code Quality
```bash
# Linter
flutter analyze

# Format code
flutter format lib/

# Run tests
flutter test
```

### Dependencies
- `flutter_riverpod`: State management
- `shared_preferences`: Local storage
- `uuid`: Unique ID generation
- `go_router`: Navigation

## 📁 **Project Structure**

### 🏗️ **Legacy Structure**
```
lib/
├── models/              # Data models
│   ├── base.dart        # Base entity
│   ├── chat_message.dart # Chat message model
│   ├── enums.dart       # Enums and constants
│   ├── invite.dart      # Invitation model
│   ├── media_ref.dart   # Media reference model
│   ├── profile.dart     # User profile model
│   └── user.dart        # User entity
├── services/            # Repository layer
│   ├── bases_repository.dart
│   ├── chat_repository.dart
│   ├── invites_repository.dart
│   ├── profile_repository.dart
│   └── session_controller.dart
├── providers/           # State management
│   ├── bases_provider.dart
│   ├── chat_provider.dart
│   ├── invites_provider.dart
│   └── providers.dart
├── screens/             # UI screens
│   ├── chat_screen.dart
│   ├── home_screen.dart
│   ├── login_screen.dart
│   ├── profile_screen.dart
│   └── splash_screen.dart
└── widgets/             # Reusable widgets
    ├── base_sidebar.dart
    ├── moon_spinner.dart
    └── primary_button.dart
```

### 🚧 **New Refactored Structure**
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

## 🎯 **Current Capabilities**

### ✅ **Working Features**
- User authentication with profile persistence
- Base creation and management
- Invitation system with code sharing
- Real-time chat with message persistence
- Base-specific chat isolation
- User identification in messages
- Message editing and deletion
- Cross-user message visibility
- Role-based access control
- Error handling and validation

### 🔄 **Ready for Extension**
- Media attachments (structure exists)
- System messages (structure exists)
- Message reactions (easy to add)
- Read receipts (easy to add)
- Typing indicators (easy to add)
- Live streaming (models ready)

## 🤝 **Contributing**

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## 📄 **Documentation**

- [Refactor Architecture](docs/REFACTOR_ARCHITECTURE.md) - New Clean Architecture implementation
- [Model Architecture](docs/MODEL_ARCHITECTURE.md) - Complete data model documentation
- [Profile Persistence](docs/PROFILE_PERSISTENCE.md) - User authentication details
- [Development Guide](docs/DEV_GUIDE.md) - Development setup and guidelines
- [Git Alias Cheat Sheet](docs/git_alias_cheat_sheet.md) - Useful git shortcuts

## 📈 **Roadmap**

### Phase 1: Legacy Proof of Concept ✅ **COMPLETE**
- [x] User authentication
- [x] Base management
- [x] Invitation system
- [x] Real-time chat
- [x] Message persistence

### Phase 2: Architecture Refactor 🚧 **IN PROGRESS**
- [x] Clean Architecture implementation
- [x] Use case pattern with validation
- [x] Repository pattern with interfaces
- [x] Type-safe ID system
- [x] Feature-based organization
- [ ] Complete test coverage
- [ ] Data persistence implementation
- [ ] UI/Widget wiring
- [ ] Session management

### Phase 3: Content Features 📋 **PLANNED**
- [ ] Media upload and display
- [ ] Posts and stories
- [ ] Content moderation

### Phase 4: Advanced Features 📋 **PLANNED**
- [ ] Live streaming
- [ ] Voice messages
- [ ] File sharing
- [ ] Reactions system
- [ ] Analytics

## 📄 **License**

This project is licensed under the MIT License.

---

**MoonBase Skeleton** - A minimal, production-ready Flutter app for closed-circle communication and content sharing.
