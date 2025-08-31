# MoonBase Model Architecture

## Overview

MoonBase is designed around the concept of "bases" - group spaces where users can chat, share media, create posts, stories, and eventually live stream. This document outlines the complete model architecture.

## Core Models

### 1. Base
The central entity representing a group space.
- **id**: Unique UUID v4 identifier
- **name**: Display name for the base
- **ownerUserId**: User who created and owns the base
- **description**: Optional description
- **memberIds**: List of user IDs who are members
- **avatarUrl**: Optional base avatar image
- **createdAt/updatedAt**: Timestamps

### 2. User
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

### 3. Profile
User preferences and settings (complements User model).
- **userId**: References User.id
- **nickname**: Case-sensitive nickname (2-24 chars)
- **themeMode**: "light" or "dark"
- **createdAt**: Profile creation timestamp

### 4. BaseMember
Represents a user's membership in a base with role-based access.
- **id**: Unique UUID v4 identifier
- **baseId**: References Base.id
- **userId**: References User.id
- **role**: owner/admin/member (BaseRole enum)
- **joinedAt/updatedAt**: Membership timestamps

## Content Models

### 5. BasePost
Content posts within a base.
- **id**: Unique UUID v4 identifier
- **baseId**: References Base.id
- **authorUserId**: References User.id
- **text**: Post content
- **media**: List of MediaRef objects
- **createdAt/updatedAt**: Timestamps

### 6. BaseStory
Ephemeral content with time-to-live.
- **id**: Unique UUID v4 identifier
- **baseId**: References Base.id
- **authorUserId**: References User.id
- **media**: Single MediaRef object
- **ttl**: Time-to-live duration
- **createdAt**: Creation timestamp
- **isExpired**: Computed property

### 7. ChatMessage
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

### 8. MediaRef
Flexible media reference system.
- **id**: Unique UUID v4 identifier
- **type**: image/video/link (MediaType enum)
- **uri**: Local path or remote URL
- **width/height**: Dimensions (for images/videos)
- **duration**: Duration (for videos/audio)
- **thumbnailUri**: Optional thumbnail

## Live Streaming

### 9. LiveSession
Live streaming sessions within bases.
- **id**: Unique UUID v4 identifier
- **baseId**: References Base.id
- **hostUserId**: References User.id
- **status**: scheduled/live/ended (LiveStatus enum)
- **createdAt/startedAt/endedAt**: Timestamps

## Invitation System

### 10. BaseInvite
Invitation codes for joining bases.
- **id**: Unique UUID v4 identifier
- **baseId**: References Base.id
- **code**: Human-shareable short code
- **createdByUserId**: References User.id
- **expiresAt**: Optional expiration
- **maxUses**: Optional usage limit
- **usedCount**: Current usage count
- **isExpired/isDepleted**: Computed properties

## Configuration

### 11. BaseSettings
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

### BaseRole
- **owner**: Base creator with full control
- **admin**: Can manage members and content
- **member**: Regular member with limited permissions

### LiveStatus
- **scheduled**: Live session is scheduled
- **live**: Currently broadcasting
- **ended**: Session has ended

### MediaType
- **image**: Image files
- **video**: Video files
- **link**: External links

### MessageType
- **text**: Text-only messages
- **media**: Messages with media
- **system**: System-generated messages

## Relationships

```
Base (1) ←→ (N) BaseMember
Base (1) ←→ (N) BasePost
Base (1) ←→ (N) BaseStory
Base (1) ←→ (N) ChatMessage
Base (1) ←→ (N) LiveSession
Base (1) ←→ (N) BaseInvite
Base (1) ←→ (1) BaseSettings

User (1) ←→ (N) BaseMember
User (1) ←→ (N) BasePost
User (1) ←→ (N) BaseStory
User (1) ←→ (N) ChatMessage
User (1) ←→ (N) LiveSession
User (1) ←→ (1) Profile
```

## Key Features

### 1. Role-Based Access Control
- Owner, admin, and member roles
- Granular permissions via BaseSettings
- Content approval workflows

### 2. Flexible Media System
- Support for images, videos, and links
- Thumbnail generation
- Duration tracking for videos

### 3. Ephemeral Content
- Stories with configurable TTL
- Automatic expiration handling

### 4. Live Streaming Foundation
- Session scheduling
- Status tracking
- Host management

### 5. Invitation System
- Shareable codes
- Expiration and usage limits
- Usage tracking

### 6. Chat Functionality
- Text and media messages
- Threaded replies
- Edit/delete support
- System messages

## Usage Examples

### Creating a Base
```dart
final base = Base(
  id: 'uuid-v4',
  name: 'My Base',
  ownerUserId: 'user-uuid',
  description: 'A cool base for sharing',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);
```

### Adding a Member
```dart
final member = BaseMember(
  id: 'uuid-v4',
  baseId: base.id,
  userId: 'user-uuid',
  role: BaseRole.member,
  joinedAt: DateTime.now(),
  updatedAt: DateTime.now(),
);
```

### Creating a Post
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

## Future Enhancements

1. **Reactions System**: Like, heart, etc. on posts/messages
2. **File Sharing**: Document and file uploads
3. **Voice Messages**: Audio recording support
4. **Polls**: Interactive polls in bases
5. **Events**: Calendar and event management
6. **Analytics**: Base activity metrics
7. **Moderation**: Content moderation tools
8. **API Integration**: Webhook support
