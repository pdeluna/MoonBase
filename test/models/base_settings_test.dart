import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/models/models.dart';

void main() {
  group('BaseSettings Model Tests', () {
    test('should create BaseSettings with required fields', () {
      final settings = BaseSettings(
        baseId: 'base-id',
        updatedAt: DateTime(2024, 1, 1),
        updatedByUserId: 'user-id',
      );

      expect(settings.baseId, 'base-id');
      expect(settings.updatedAt, DateTime(2024, 1, 1));
      expect(settings.updatedByUserId, 'user-id');
      expect(settings.allowMemberInvites, false);
      expect(settings.allowMemberPosts, true);
      expect(settings.allowMemberStories, true);
      expect(settings.allowMemberChat, true);
      expect(settings.requireApprovalForPosts, false);
      expect(settings.requireApprovalForStories, false);
      expect(settings.maxMediaPerPost, 10);
      expect(settings.maxMediaPerStory, 1);
      expect(settings.storyTtl, const Duration(hours: 24));
      expect(settings.enableLiveStreaming, true);
      expect(settings.enableReactions, true);
      expect(settings.allowedMediaTypes, ['image', 'video', 'link']);
    });

    test('should create BaseSettings with custom values', () {
      final settings = BaseSettings(
        baseId: 'base-id',
        allowMemberInvites: true,
        allowMemberPosts: false,
        allowMemberStories: false,
        allowMemberChat: false,
        requireApprovalForPosts: true,
        requireApprovalForStories: true,
        maxMediaPerPost: 5,
        maxMediaPerStory: 2,
        storyTtl: const Duration(hours: 12),
        enableLiveStreaming: false,
        enableReactions: false,
        allowedMediaTypes: ['image'],
        updatedAt: DateTime(2024, 1, 1),
        updatedByUserId: 'user-id',
      );

      expect(settings.allowMemberInvites, true);
      expect(settings.allowMemberPosts, false);
      expect(settings.allowMemberStories, false);
      expect(settings.allowMemberChat, false);
      expect(settings.requireApprovalForPosts, true);
      expect(settings.requireApprovalForStories, true);
      expect(settings.maxMediaPerPost, 5);
      expect(settings.maxMediaPerStory, 2);
      expect(settings.storyTtl, const Duration(hours: 12));
      expect(settings.enableLiveStreaming, false);
      expect(settings.enableReactions, false);
      expect(settings.allowedMediaTypes, ['image']);
    });

    test('should serialize and deserialize correctly', () {
      final original = BaseSettings(
        baseId: 'base-id',
        allowMemberInvites: true,
        allowMemberPosts: false,
        allowMemberStories: true,
        allowMemberChat: true,
        requireApprovalForPosts: true,
        requireApprovalForStories: false,
        maxMediaPerPost: 5,
        maxMediaPerStory: 2,
        storyTtl: const Duration(hours: 12),
        enableLiveStreaming: false,
        enableReactions: true,
        allowedMediaTypes: ['image', 'video'],
        updatedAt: DateTime(2024, 1, 1, 12, 0, 0),
        updatedByUserId: 'user-id',
      );

      final json = original.toMap();
      final restored = BaseSettings.fromMap(json);

      expect(restored.baseId, original.baseId);
      expect(restored.allowMemberInvites, original.allowMemberInvites);
      expect(restored.allowMemberPosts, original.allowMemberPosts);
      expect(restored.allowMemberStories, original.allowMemberStories);
      expect(restored.allowMemberChat, original.allowMemberChat);
      expect(restored.requireApprovalForPosts, original.requireApprovalForPosts);
      expect(restored.requireApprovalForStories, original.requireApprovalForStories);
      expect(restored.maxMediaPerPost, original.maxMediaPerPost);
      expect(restored.maxMediaPerStory, original.maxMediaPerStory);
      expect(restored.storyTtl, original.storyTtl);
      expect(restored.enableLiveStreaming, original.enableLiveStreaming);
      expect(restored.enableReactions, original.enableReactions);
      expect(restored.allowedMediaTypes, original.allowedMediaTypes);
      expect(restored.updatedAt, original.updatedAt);
      expect(restored.updatedByUserId, original.updatedByUserId);
    });

    test('should handle JSON serialization', () {
      final settings = BaseSettings(
        baseId: 'base-id',
        updatedAt: DateTime(2024, 1, 1),
        updatedByUserId: 'user-id',
      );

      final jsonString = settings.toJson();
      final restored = BaseSettings.fromJson(jsonString);

      expect(restored.baseId, settings.baseId);
      expect(restored.updatedAt, settings.updatedAt);
      expect(restored.updatedByUserId, settings.updatedByUserId);
    });

    test('should handle copyWith correctly', () {
      final original = BaseSettings(
        baseId: 'base-id',
        updatedAt: DateTime(2024, 1, 1),
        updatedByUserId: 'user-id',
      );

      final updated = original.copyWith(
        allowMemberInvites: true,
        allowMemberPosts: false,
        maxMediaPerPost: 5,
        storyTtl: const Duration(hours: 12),
        enableLiveStreaming: false,
        allowedMediaTypes: ['image'],
        updatedAt: DateTime(2024, 1, 2),
        updatedByUserId: 'new-user-id',
      );

      expect(updated.baseId, original.baseId);
      expect(updated.allowMemberInvites, true);
      expect(updated.allowMemberPosts, false);
      expect(updated.maxMediaPerPost, 5);
      expect(updated.storyTtl, const Duration(hours: 12));
      expect(updated.enableLiveStreaming, false);
      expect(updated.allowedMediaTypes, ['image']);
      expect(updated.updatedAt, DateTime(2024, 1, 2));
      expect(updated.updatedByUserId, 'new-user-id');
      expect(updated.allowMemberStories, original.allowMemberStories);
      expect(updated.allowMemberChat, original.allowMemberChat);
    });

    test('should handle equality correctly', () {
      final settings1 = BaseSettings(
        baseId: 'base-id',
        updatedAt: DateTime(2024, 1, 1),
        updatedByUserId: 'user-id',
      );

      final settings2 = BaseSettings(
        baseId: 'base-id',
        allowMemberInvites: true,
        allowMemberPosts: false,
        updatedAt: DateTime(2024, 1, 2),
        updatedByUserId: 'different-user',
      );

      final settings3 = BaseSettings(
        baseId: 'different-base-id',
        updatedAt: DateTime(2024, 1, 1),
        updatedByUserId: 'user-id',
      );

      expect(settings1, equals(settings2)); // Same baseId
      expect(settings1, isNot(equals(settings3))); // Different baseId
    });

    test('should handle hashCode correctly', () {
      final settings1 = BaseSettings(
        baseId: 'base-id',
        updatedAt: DateTime(2024, 1, 1),
        updatedByUserId: 'user-id',
      );

      final settings2 = BaseSettings(
        baseId: 'base-id',
        allowMemberInvites: true,
        allowMemberPosts: false,
        updatedAt: DateTime(2024, 1, 2),
        updatedByUserId: 'different-user',
      );

      expect(settings1.hashCode, equals(settings2.hashCode));
    });

    test('should handle null values in fromMap', () {
      final map = {
        'baseId': 'base-id',
        'allowMemberInvites': null,
        'allowMemberPosts': null,
        'allowMemberStories': null,
        'allowMemberChat': null,
        'requireApprovalForPosts': null,
        'requireApprovalForStories': null,
        'maxMediaPerPost': null,
        'maxMediaPerStory': null,
        'storyTtlMs': null,
        'enableLiveStreaming': null,
        'enableReactions': null,
        'allowedMediaTypes': null,
        'updatedAt': '2024-01-01T00:00:00.000Z',
        'updatedByUserId': 'user-id',
      };

      final settings = BaseSettings.fromMap(map);
      expect(settings.allowMemberInvites, false);
      expect(settings.allowMemberPosts, true);
      expect(settings.allowMemberStories, true);
      expect(settings.allowMemberChat, true);
      expect(settings.requireApprovalForPosts, false);
      expect(settings.requireApprovalForStories, false);
      expect(settings.maxMediaPerPost, 10);
      expect(settings.maxMediaPerStory, 1);
      expect(settings.storyTtl, const Duration(hours: 24));
      expect(settings.enableLiveStreaming, true);
      expect(settings.enableReactions, true);
      expect(settings.allowedMediaTypes, ['image', 'video', 'link']);
    });

    test('should handle storyTtl serialization correctly', () {
      final settings = BaseSettings(
        baseId: 'base-id',
        storyTtl: const Duration(hours: 12, minutes: 30),
        updatedAt: DateTime(2024, 1, 1),
        updatedByUserId: 'user-id',
      );

      final json = settings.toMap();
      expect(json['storyTtlMs'], 45000000); // 12.5 hours in milliseconds

      final restored = BaseSettings.fromMap(json);
      expect(restored.storyTtl, const Duration(hours: 12, minutes: 30));
    });
  });
}
