import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/models/models.dart';

void main() {
  group('All Models Integration Tests', () {
    test('should create complete base ecosystem', () {
      // Create a base
      final base = Base(
        id: 'base-1',
        name: 'Test Base',
        ownerUserId: 'user-1',
        description: 'A test base for integration testing',
        memberIds: ['user-1', 'user-2'],
        avatarUrl: 'https://example.com/base-avatar.jpg',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      // Create users
      final user1 = User(
        id: 'user-1',
        email: 'user1@example.com',
        username: 'user1',
        displayName: 'User One',
        avatarUrl: 'https://example.com/user1-avatar.jpg',
        isEmailVerified: true,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        baseIds: ['base-1'],
      );

      final user2 = User(
        id: 'user-2',
        email: 'user2@example.com',
        username: 'user2',
        displayName: 'User Two',
        avatarUrl: 'https://example.com/user2-avatar.jpg',
        isEmailVerified: true,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        baseIds: ['base-1'],
      );

      // Create base members
      final ownerMember = BaseMember(
        id: 'member-1',
        baseId: 'base-1',
        userId: 'user-1',
        role: BaseRole.owner,
        joinedAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final memberMember = BaseMember(
        id: 'member-2',
        baseId: 'base-1',
        userId: 'user-2',
        role: BaseRole.member,
        joinedAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      // Create base settings
      final settings = BaseSettings(
        baseId: 'base-1',
        allowMemberInvites: true,
        allowMemberPosts: true,
        allowMemberStories: true,
        allowMemberChat: true,
        requireApprovalForPosts: false,
        requireApprovalForStories: false,
        maxMediaPerPost: 5,
        maxMediaPerStory: 1,
        storyTtl: const Duration(hours: 24),
        enableLiveStreaming: true,
        enableReactions: true,
        allowedMediaTypes: ['image', 'video', 'link'],
        updatedAt: DateTime(2024, 1, 1),
        updatedByUserId: 'user-1',
      );

      // Create media references
      const imageMedia = MediaRef(
        id: 'media-1',
        type: MediaType.image,
        uri: 'https://example.com/image.jpg',
        width: 800,
        height: 600,
        thumbnailUri: 'https://example.com/image-thumb.jpg',
      );

      const videoMedia = MediaRef(
        id: 'media-2',
        type: MediaType.video,
        uri: 'https://example.com/video.mp4',
        width: 1920,
        height: 1080,
        duration: Duration(minutes: 2, seconds: 30),
        thumbnailUri: 'https://example.com/video-thumb.jpg',
      );

      // Create posts
      final post = BasePost(
        id: 'post-1',
        baseId: 'base-1',
        authorUserId: 'user-1',
        text: 'Hello everyone!',
        media: [imageMedia],
        createdAt: DateTime(2024, 1, 1, 12, 0, 0),
        updatedAt: DateTime(2024, 1, 1, 12, 0, 0),
      );

      // Create stories
      final story = BaseStory(
        id: 'story-1',
        baseId: 'base-1',
        authorUserId: 'user-2',
        media: videoMedia,
        ttl: const Duration(hours: 24),
        createdAt: DateTime(2025, 12, 31, 12, 0, 0), // Future date, definitely not expired
      );

      // Create chat messages
      final textMessage = ChatMessage(
        id: 'message-1',
        baseId: 'base-1',
        authorUserId: 'user-1',
        type: MessageType.text,
        text: 'Hello everyone!',
        createdAt: DateTime(2024, 1, 1, 15, 0, 0),
      );

      final mediaMessage = ChatMessage(
        id: 'message-2',
        baseId: 'base-1',
        authorUserId: 'user-2',
        type: MessageType.media,
        text: 'Check this out!',
        media: [imageMedia],
        createdAt: DateTime(2024, 1, 1, 15, 30, 0),
      );

      final replyMessage = ChatMessage(
        id: 'message-3',
        baseId: 'base-1',
        authorUserId: 'user-1',
        type: MessageType.text,
        text: 'Nice!',
        replyToMessageId: 'message-2',
        createdAt: DateTime(2024, 1, 1, 15, 35, 0),
      );

      // Create live session
      final liveSession = LiveSession(
        id: 'live-1',
        baseId: 'base-1',
        hostUserId: 'user-1',
        status: LiveStatus.scheduled,
        createdAt: DateTime(2024, 1, 1, 16, 0, 0),
      );

      // Create invite
      final invite = BaseInvite(
        id: 'invite-1',
        baseId: 'base-1',
        code: 'ABC123',
        createdByUserId: 'user-1',
        createdAt: DateTime(2024, 1, 1, 17, 0, 0),
        expiresAt: DateTime(2025, 12, 31, 17, 0, 0), // Future date, not expired
        maxUses: 10,
        usedCount: 0,
      );

      // Verify relationships
      expect(base.memberIds, containsAll(['user-1', 'user-2']));
      expect(user1.baseIds, contains('base-1'));
      expect(user2.baseIds, contains('base-1'));

      expect(ownerMember.baseId, base.id);
      expect(ownerMember.userId, user1.id);
      expect(ownerMember.role, BaseRole.owner);

      expect(memberMember.baseId, base.id);
      expect(memberMember.userId, user2.id);
      expect(memberMember.role, BaseRole.member);

      expect(settings.baseId, base.id);
      expect(post.baseId, base.id);
      expect(post.authorUserId, user1.id);
      expect(story.baseId, base.id);
      expect(story.authorUserId, user2.id);
      expect(textMessage.baseId, base.id);
      expect(mediaMessage.baseId, base.id);
      expect(liveSession.baseId, base.id);
      expect(liveSession.hostUserId, user1.id);
      expect(invite.baseId, base.id);
      expect(invite.createdByUserId, user1.id);

      // Verify media relationships
      expect(post.media, hasLength(1));
      expect(post.media.first.id, imageMedia.id);
      expect(story.media.id, videoMedia.id);
      expect(mediaMessage.media, hasLength(1));
      expect(mediaMessage.media!.first.id, imageMedia.id);

      // Verify message threading
      expect(replyMessage.replyToMessageId, mediaMessage.id);

      // Verify story expiration
      expect(story.isExpired, false);
      expect(story.ttl, const Duration(hours: 24));

      // Verify invite properties
      expect(invite.isExpired, false);
      expect(invite.isDepleted, false);
    });

    test('should handle serialization of complete ecosystem', () {
      // Create a complete base ecosystem
      final base = Base(
        id: 'base-1',
        name: 'Test Base',
        ownerUserId: 'user-1',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final user = User(
        id: 'user-1',
        email: 'user@example.com',
        username: 'user1',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final member = BaseMember(
        id: 'member-1',
        baseId: 'base-1',
        userId: 'user-1',
        role: BaseRole.owner,
        joinedAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final settings = BaseSettings(
        baseId: 'base-1',
        updatedAt: DateTime(2024, 1, 1),
        updatedByUserId: 'user-1',
      );

      const media = MediaRef(
        id: 'media-1',
        type: MediaType.image,
        uri: 'https://example.com/image.jpg',
      );

      final post = BasePost(
        id: 'post-1',
        baseId: 'base-1',
        authorUserId: 'user-1',
        text: 'Hello world!',
        media: [media],
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final story = BaseStory(
        id: 'story-1',
        baseId: 'base-1',
        authorUserId: 'user-1',
        media: media,
        ttl: const Duration(hours: 24),
        createdAt: DateTime(2025, 12, 31, 12, 0, 0), // Future date, definitely not expired
      );

      final message = ChatMessage(
        id: 'message-1',
        baseId: 'base-1',
        authorUserId: 'user-1',
        type: MessageType.text,
        text: 'Hello!',
        createdAt: DateTime(2024, 1, 1),
      );

      final liveSession = LiveSession(
        id: 'live-1',
        baseId: 'base-1',
        hostUserId: 'user-1',
        status: LiveStatus.scheduled,
        createdAt: DateTime(2024, 1, 1),
      );

      final invite = BaseInvite(
        id: 'invite-1',
        baseId: 'base-1',
        code: 'ABC123',
        createdByUserId: 'user-1',
        createdAt: DateTime(2024, 1, 1),
        expiresAt: DateTime(2025, 12, 31, 17, 0, 0), // Future date
        maxUses: 10,
        usedCount: 0,
      );

      // Test serialization and deserialization
      final baseJson = base.toJson();
      final userJson = user.toJson();
      final memberJson = member.toJson();
      final settingsJson = settings.toJson();
      final mediaJson = media.toJson();
      final postJson = post.toJson();
      final storyJson = story.toJson();
      final messageJson = message.toJson();
      final liveSessionJson = liveSession.toJson();
      final inviteJson = invite.toJson();

      // Test deserialization
      final restoredBase = Base.fromJson(baseJson);
      final restoredUser = User.fromJson(userJson);
      final restoredMember = BaseMember.fromJson(memberJson);
      final restoredSettings = BaseSettings.fromJson(settingsJson);
      final restoredMedia = MediaRef.fromJson(mediaJson);
      final restoredPost = BasePost.fromJson(postJson);
      final restoredStory = BaseStory.fromJson(storyJson);
      final restoredMessage = ChatMessage.fromJson(messageJson);
      final restoredLiveSession = LiveSession.fromJson(liveSessionJson);
      final restoredInvite = BaseInvite.fromJson(inviteJson);

      // Verify all objects are restored correctly
      expect(restoredBase.id, base.id);
      expect(restoredUser.id, user.id);
      expect(restoredMember.id, member.id);
      expect(restoredSettings.baseId, settings.baseId);
      expect(restoredMedia.id, media.id);
      expect(restoredPost.id, post.id);
      expect(restoredStory.id, story.id);
      expect(restoredMessage.id, message.id);
      expect(restoredLiveSession.id, liveSession.id);
      expect(restoredInvite.id, invite.id);
    });

    test('should handle model equality correctly', () {
      final base1 = Base(
        id: 'base-1',
        name: 'Base 1',
        ownerUserId: 'user-1',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final base2 = Base(
        id: 'base-1',
        name: 'Base 2',
        ownerUserId: 'user-2',
        createdAt: DateTime(2024, 1, 2),
        updatedAt: DateTime(2024, 1, 2),
      );

      final base3 = Base(
        id: 'base-2',
        name: 'Base 1',
        ownerUserId: 'user-1',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      expect(base1, equals(base2)); // Same ID
      expect(base1, isNot(equals(base3))); // Different ID
      expect(base1.hashCode, equals(base2.hashCode));
      expect(base1.hashCode, isNot(equals(base3.hashCode)));
    });
  });
}
