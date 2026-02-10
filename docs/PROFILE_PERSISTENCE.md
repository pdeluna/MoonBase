# Profile Persistence Implementation

## Overview

This implementation provides profile persistence using UUID-based identification with case-sensitive nicknames, including theme support (light/dark mode). Still relevant to the auth feature in `lib/features/auth/`.

## Key Features

### 1. UUID-Based Profile Identification
- Each profile gets a unique UUID v4 identifier
- UUIDs are generated using the `uuid` package
- Profiles are uniquely identified by their UUID, not just nickname

### 2. Case-Sensitive Nicknames
- Nicknames are stored and retrieved exactly as entered
- "Alice", "alice", and "ALICE" are treated as different profiles
- Each case variation gets its own UUID and profile data

### 3. Theme Persistence
- Theme preference (light/dark) is stored per profile
- Theme changes are persisted immediately
- Theme state is restored on app restart

### 4. Startup Flow
- Splash screen shows while profile is loading
- Automatic redirect to login if no profile exists
- Automatic redirect to home if profile exists
- Router handles all authentication state changes

## Implementation Details

### Storage Structure
```
SharedPreferences:
- mb.users: JSON object { nickname_case_sensitive : <Profile JSON> }
- mb.currentUser: string nickname_case_sensitive
```

### Profile Model
```dart
class Profile {
  final String userId;     // UUID v4
  final String nickname;   // Case-sensitive, 2-24 chars
  final String createdAt;  // ISO-8601 timestamp
  final String themeMode;  // "light" or "dark"
}
```

### Key Components

1. **SessionController** (`lib/services/session_controller.dart`)
   - Manages authentication state
   - Handles sign in/out operations
   - Updates theme preferences

2. **ProfileRepository** (`lib/services/profile_repository.dart`)
   - Handles profile persistence
   - Manages case-sensitive nickname storage
   - Provides UUID generation

3. **Router** (`lib/router.dart`)
   - Handles startup redirects
   - Manages authentication-based navigation
   - Prevents unauthorized access

## Usage Examples

### Creating a Profile
```dart
// Different case variations create different profiles
await sessionController.signIn('Alice');    // Creates profile with UUID
await sessionController.signIn('alice');    // Creates different profile
await sessionController.signIn('ALICE');    // Creates another profile
```

### Theme Management
```dart
// Update theme preference
await sessionController.updateTheme('dark');

// Theme is automatically applied and persisted
```

### Profile Retrieval
```dart
// Get current profile
final profile = await repository.read();
if (profile != null) {
  print('User: ${profile.nickname}');
  print('UUID: ${profile.userId}');
  print('Theme: ${profile.themeMode}');
}
```

## Testing

Run the profile persistence tests:
```bash
flutter test test/profile_persistence_test.dart
```

Tests verify:
- Case-sensitive nickname handling
- UUID generation and validation
- Theme persistence
- Profile creation and retrieval
- Sign out functionality

## Migration

The implementation includes automatic migration from legacy single-profile storage to the new multi-profile system. Existing profiles are automatically migrated on first app launch.
