import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/models/models.dart';

void main() {
  group('User Model Tests', () {
    test('should create User with required fields', () {
      final user = User(
        id: 'test-id',
        email: 'test@example.com',
        username: 'testuser',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      expect(user.id, 'test-id');
      expect(user.email, 'test@example.com');
      expect(user.username, 'testuser');
      expect(user.displayName, isNull);
      expect(user.avatarUrl, isNull);
      expect(user.isEmailVerified, false);
      expect(user.isActive, true);
      expect(user.baseIds, isEmpty);
      expect(user.lastSeenAt, isNull);
    });

    test('should create User with all fields', () {
      final user = User(
        id: 'test-id',
        email: 'test@example.com',
        username: 'testuser',
        displayName: 'Test User',
        avatarUrl: 'https://example.com/avatar.jpg',
        isEmailVerified: true,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        lastSeenAt: DateTime(2024, 1, 1, 12, 0, 0),
        isActive: false,
        baseIds: ['base1', 'base2'],
      );

      expect(user.displayName, 'Test User');
      expect(user.avatarUrl, 'https://example.com/avatar.jpg');
      expect(user.isEmailVerified, true);
      expect(user.isActive, false);
      expect(user.baseIds, ['base1', 'base2']);
      expect(user.lastSeenAt, DateTime(2024, 1, 1, 12, 0, 0));
    });

    test('should serialize and deserialize correctly', () {
      final original = User(
        id: 'test-id',
        email: 'test@example.com',
        username: 'testuser',
        displayName: 'Test User',
        avatarUrl: 'https://example.com/avatar.jpg',
        isEmailVerified: true,
        createdAt: DateTime(2024, 1, 1, 12, 0, 0),
        updatedAt: DateTime(2024, 1, 1, 12, 0, 0),
        lastSeenAt: DateTime(2024, 1, 1, 12, 0, 0),
        isActive: false,
        baseIds: ['base1', 'base2'],
      );

      final json = original.toMap();
      final restored = User.fromMap(json);

      expect(restored.id, original.id);
      expect(restored.email, original.email);
      expect(restored.username, original.username);
      expect(restored.displayName, original.displayName);
      expect(restored.avatarUrl, original.avatarUrl);
      expect(restored.isEmailVerified, original.isEmailVerified);
      expect(restored.isActive, original.isActive);
      expect(restored.baseIds, original.baseIds);
      expect(restored.lastSeenAt, original.lastSeenAt);
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
    });

    test('should handle JSON serialization', () {
      final user = User(
        id: 'test-id',
        email: 'test@example.com',
        username: 'testuser',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final jsonString = user.toJson();
      final restored = User.fromJson(jsonString);

      expect(restored.id, user.id);
      expect(restored.email, user.email);
      expect(restored.username, user.username);
    });

    test('should handle copyWith correctly', () {
      final original = User(
        id: 'test-id',
        email: 'test@example.com',
        username: 'testuser',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final updated = original.copyWith(
        displayName: 'Updated Name',
        avatarUrl: 'https://example.com/new-avatar.jpg',
        isEmailVerified: true,
        baseIds: ['new-base'],
      );

      expect(updated.id, original.id);
      expect(updated.email, original.email);
      expect(updated.username, original.username);
      expect(updated.displayName, 'Updated Name');
      expect(updated.avatarUrl, 'https://example.com/new-avatar.jpg');
      expect(updated.isEmailVerified, true);
      expect(updated.baseIds, ['new-base']);
      expect(updated.createdAt, original.createdAt);
      expect(updated.updatedAt, original.updatedAt);
    });

    test('should handle equality correctly', () {
      final user1 = User(
        id: 'test-id',
        email: 'test@example.com',
        username: 'testuser',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final user2 = User(
        id: 'test-id',
        email: 'different@example.com',
        username: 'differentuser',
        createdAt: DateTime(2024, 1, 2),
        updatedAt: DateTime(2024, 1, 2),
      );

      final user3 = User(
        id: 'different-id',
        email: 'test@example.com',
        username: 'testuser',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      expect(user1, equals(user2)); // Same ID
      expect(user1, isNot(equals(user3))); // Different ID
    });

    test('should handle hashCode correctly', () {
      final user1 = User(
        id: 'test-id',
        email: 'test@example.com',
        username: 'testuser',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final user2 = User(
        id: 'test-id',
        email: 'different@example.com',
        username: 'differentuser',
        createdAt: DateTime(2024, 1, 2),
        updatedAt: DateTime(2024, 1, 2),
      );

      expect(user1.hashCode, equals(user2.hashCode));
    });

    test('should handle null values in fromMap', () {
      final map = {
        'id': 'test-id',
        'email': 'test@example.com',
        'username': 'testuser',
        'displayName': null,
        'avatarUrl': null,
        'isEmailVerified': null,
        'isActive': null,
        'baseIds': null,
        'lastSeenAt': null,
        'createdAt': '2024-01-01T00:00:00.000Z',
        'updatedAt': '2024-01-01T00:00:00.000Z',
      };

      final user = User.fromMap(map);
      expect(user.displayName, isNull);
      expect(user.avatarUrl, isNull);
      expect(user.isEmailVerified, false);
      expect(user.isActive, true);
      expect(user.baseIds, isEmpty);
      expect(user.lastSeenAt, isNull);
    });
  });
}
