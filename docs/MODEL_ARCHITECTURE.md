# MoonBase Model Architecture

## Overview

MoonBase is designed around the concept of "bases" — group spaces where users can chat, share media, create posts, stories, and eventually live stream. This document outlines the model architecture and implementation status. **Domain entities** for the current 3-layer architecture live under `lib/features/<feature>/domain/entities/`; some names and concepts here may align with legacy models in `lib/models/` for context.

## Implementation Status

### ✅ **FULLY IMPLEMENTED**
- **Base Management**: Create, read, update bases with full CRUD operations
- **User Authentication**: Profile-based authentication with persistence
- **Invitation System**: Complete invite creation, redemption, and tracking
- **Chat System**: Full real-time messaging with persistence and base isolation
- **Base Membership**: Role-based access control (owner, admin, member)

### 🚧 **PARTIALLY IMPLEMENTED**
- **Media System**: Data models ready, UI implementation pending
- **Posts & Stories**: Data models defined, repository layer pending
- **Live Streaming**: Data models ready, implementation pending

### 📋 **PLANNED**
- **Reactions System**: Like, heart, etc. on posts/messages
- **File Sharing**: Document and file uploads
- **Voice Messages**: Audio recording support
- **Polls**: Interactive polls in bases
- **Events**: Calendar and event management

## Core Models

### 1. Base ✅ **IMPLEMENTED**
The central entity representing a group space.
- **id**: Unique UUID v4 identifier
- **name**: Display name for the base
- **ownerUserId**: User who created and owns the base
- **description**: Optional description
- **createdAt**: Creation timestamp

**Repository**: `SpBasesRepository` - Full CRUD operations
**Provider**: `basesProvider` - State management with real-time updates

### 2. User ✅ **IMPLEMENTED**
Represents a user account in the system.
- **id**: Unique UUID v4 identifier
- **email**: User's email address
- **username**: Unique, case-insensitive username
- **displayName**: Optional display name
- **avatarUrl**: User's profile picture
- **isEmailVerified**: Email verification status
- **baseIds**: List of bases this user is a member of
- **lastSeenAt**: Last activity timestamp
- **isActive**: Account status

### 3. Profile ✅ **IMPLEMENTED**
User preferences and settings (complements User model).
- **userId**: References User.id
- **nickname**: Case-sensitive nickname (2-24 chars)
- **themeMode**: "light" or "dark"
- **createdAt**: Profile creation timestamp

**Repository**: `SpProfileRepository` - Profile persistence and authentication
**Provider**: `sessionProvider` - Session management with real-time state

### 4. BaseMember ✅ **IMPLEMENTED**
Represents a user's membership in a base with role-based access.
- **id**: Unique UUID v4 identifier
- **baseId**: References Base.id
- **userId**: References User.id
- **role**: owner/admin/member (BaseRole enum)
- **joinedAt/updatedAt**: Membership timestamps

**Repository**: Integrated with `SpBasesRepository`
**Provider**: Integrated with `basesProvider`

## Content Models

### 5. BasePost 📋 **PLANNED**
Content posts within a base.
- **id**: Unique UUID v4 identifier
- **baseId**: References Base.id
- **authorUserId**: References User.id
- **text**: Post content
- **media**: List of MediaRef objects
- **createdAt/updatedAt**: Timestamps

### 6. BaseStory 📋 **PLANNED**
Ephemeral content with time-to-live.
- **id**: Unique UUID v4 identifier
- **baseId**: References Base.id
- **authorUserId**: References User.id
- **media**: Single MediaRef object
- **ttl**: Time-to-live duration
- **createdAt**: Creation timestamp
- **isExpired**: Computed property

### 7. ChatMessage ✅ **FULLY IMPLEMENTED**
Messages in base chat channels.
- **id**: Unique UUID v4 identifier
- **baseId**: References Base.id
- **authorUserId**: References User.id
- **type**: text/media/system (MessageType enum)
- **text**: Message content
- **media**: List of MediaRef objects
- **replyToMessageId**: For threaded replies
- **isEdited/isDeleted**: Status flags
- **createdAt/editedAt**: Timestamps

**Repository**: `SpChatRepository` - Full chat operations with real-time streaming
**Providers**: 
- `chatMessagesProvider` - Message state management
- `chatStreamProvider` - Real-time message updates
- `chatActionsProvider` - Send, edit, delete operations

**Features**:
- ✅ Real-time messaging with streams
- ✅ Message persistence across app restarts
- ✅ Base-specific chat isolation
- ✅ User authentication and identification
- ✅ Message editing and soft deletion
- ✅ Pagination and message retrieval
- ✅ Error handling and validation

### 8. MediaRef 🚧 **MODEL READY**
Flexible media reference system.
- **id**: Unique UUID v4 identifier
- **type**: image/video/link (MediaType enum)
- **uri**: Local path or remote URL
- **width/height**: Dimensions (for images/videos)
- **duration**: Duration (for videos/audio)
- **thumbnailUri**: Optional thumbnail

**Status**: Data model implemented, UI integration pending

## Live Streaming

### 9. LiveSession 📋 **PLANNED**
Live streaming sessions within bases.
- **id**: Unique UUID v4 identifier
- **baseId**: References Base.id
- **hostUserId**: References User.id
- **status**: scheduled/live/ended (LiveStatus enum)
- **createdAt/startedAt/endedAt**: Timestamps

## Invitation System

### 10. BaseInvite ✅ **FULLY IMPLEMENTED**
Invitation codes for joining bases.
- **id**: Unique UUID v4 identifier
- **baseId**: References Base.id
- **code**: Human-shareable short code
- **createdByUserId**: References User.id
- **expiresAt**: Optional expiration
- **maxUses**: Optional usage limit
- **usedCount**: Current usage count
- **isExpired/isDepleted**: Computed properties

**Repository**: `SpInvitesRepository` - Complete invite management
**Provider**: `invitesProvider` - State management

**Features**:
- ✅ Invite creation with customizable limits
- ✅ Invite redemption and validation
- ✅ Usage tracking and expiration
- ✅ Base membership integration

## Configuration

### 11. BaseSettings 📋 **PLANNED**
Base-specific configuration and permissions.
- **baseId**: References Base.id
- **allowMemberInvites**: Can members invite others
- **allowMemberPosts**: Can members create posts
- **allowMemberStories**: Can members create stories
- **allowMemberChat**: Can members send messages
- **requireApprovalForPosts**: Posts need admin approval
- **requireApprovalForStories**: Stories need admin approval
- **maxMediaPerPost**: Max media items per post
- **maxMediaPerStory**: Max media items per story
- **storyTtl**: Default story time-to-live
- **enableLiveStreaming**: Allow live sessions
- **enableReactions**: Allow reactions
- **allowedMediaTypes**: Allowed media types
- **updatedAt/updatedByUserId**: Change tracking

## Enums

### BaseRole ✅ **IMPLEMENTED**
- **owner**: Base creator with full control
- **admin**: Can manage members and content
- **member**: Regular member with limited permissions

### LiveStatus 📋 **PLANNED**
- **scheduled**: Live session is scheduled
- **live**: Currently broadcasting
- **ended**: Session has ended

### MediaType 🚧 **MODEL READY**
- **image**: Image files
- **video**: Video files
- **link**: External links

### MessageType ✅ **IMPLEMENTED**
- **text**: Text-only messages
- **media**: Messages with media
- **system**: System-generated messages

## Relationships

```
Base (1) ←→ (N) BaseMember ✅
Base (1) ←→ (N) BasePost 📋
Base (1) ←→ (N) BaseStory 📋
Base (1) ←→ (N) ChatMessage ✅
Base (1) ←→ (N) LiveSession 📋
Base (1) ←→ (N) BaseInvite ✅
Base (1) ←→ (1) BaseSettings 📋

User (1) ←→ (N) BaseMember ✅
User (1) ←→ (N) BasePost 📋
User (1) ←→ (N) BaseStory 📋
User (1) ←→ (N) ChatMessage ✅
User (1) ←→ (N) LiveSession 📋
User (1) ←→ (1) Profile ✅
```

## Key Features

### 1. Role-Based Access Control ✅ **IMPLEMENTED**
- Owner, admin, and member roles
- Base membership validation
- Permission-based operations

### 2. Flexible Media System 🚧 **MODEL READY**
- Support for images, videos, and links
- Thumbnail generation (planned)
- Duration tracking for videos (planned)

### 3. Ephemeral Content 📋 **PLANNED**
- Stories with configurable TTL
- Automatic expiration handling

### 4. Live Streaming Foundation 📋 **PLANNED**
- Session scheduling
- Status tracking
- Host management

### 5. Invitation System ✅ **FULLY IMPLEMENTED**
- Shareable codes
- Expiration and usage limits
- Usage tracking
- Base membership integration

### 6. Chat Functionality ✅ **FULLY IMPLEMENTED**
- Text and media messages
- Threaded replies (structure ready)
- Edit/delete support
- System messages (structure ready)
- Real-time streaming
- Message persistence
- Base isolation
- User authentication

## Current Architecture

### Repository Layer ✅ **IMPLEMENTED**
```
SpBasesRepository     - Base CRUD operations
SpProfileRepository   - User authentication & profiles
SpInvitesRepository   - Invitation management
SpChatRepository      - Chat message operations
```

### Provider Layer ✅ **IMPLEMENTED**
```
basesProvider         - Base state management
sessionProvider       - User session management
invitesProvider       - Invite state management
chatMessagesProvider  - Message state (per base)
chatStreamProvider    - Real-time updates (per base)
chatActionsProvider   - Message actions
```

### UI Layer ✅ **IMPLEMENTED**
```
LoginScreen           - User authentication
HomeScreen            - Base selection & management
ChatScreen            - Real-time messaging
ProfileScreen         - User profile management
BasePickerScreen      - Base selection
```

## Usage Examples

### Creating a Base ✅ **IMPLEMENTED**
```dart
final base = await basesRepository.createBase(
  name: 'My Base',
  description: 'A cool base for sharing',
  userId: 'user-uuid',
);
```

### Adding a Member ✅ **IMPLEMENTED**
```dart
// Via invite system
final invite = await invitesRepository.createInvite(
  baseId: base.id,
  userId: 'user-uuid',
  maxUses: 5,
);

final member = await invitesRepository.redeemInvite(
  code: invite.code,
  userId: 'new-user-uuid',
);
```

### Sending a Chat Message ✅ **IMPLEMENTED**
```dart
final message = await chatRepository.sendMessage(
  baseId: base.id,
  authorUserId: 'user-uuid',
  type: MessageType.text,
  text: 'Hello world!',
);
```

### Creating a Post 📋 **PLANNED**
```dart
final post = BasePost(
  id: 'uuid-v4',
  baseId: base.id,
  authorUserId: 'user-uuid',
  text: 'Hello world!',
  media: [mediaRef],
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);
```

## Testing

### ✅ **IMPLEMENTED TESTS**
- **Unit Tests**: All repository methods
- **Integration Tests**: Complete user flows
- **Widget Tests**: Basic UI components

### Test Coverage
```
chat_repository_test.dart     - 14 tests ✅
integration_test.dart         - 3 tests ✅
bases_repository_test.dart    - 15 tests ✅
invites_repository_test.dart  - 12 tests ✅
```

## Next Development Priorities

1. **Media System UI** 🚧 - Implement media upload and display
2. **Posts & Stories** 📋 - Complete content creation system
3. **Live Streaming** 📋 - Implement streaming functionality
4. **Reactions System** 📋 - Add like/heart reactions
5. **File Sharing** 📋 - Document upload support
6. **Voice Messages** 📋 - Audio recording support

## Technical Stack

- **Framework**: Flutter 3.22+
- **State Management**: Riverpod 2.5+
- **Storage**: SharedPreferences (local)
- **Navigation**: GoRouter 14.2+
- **Testing**: Flutter Test
- **Code Quality**: Flutter Lints 4.0+
