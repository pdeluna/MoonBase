import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/profile/domain/entities/profile.dart';

void main() {
  group('Profile Entity', () {
    test('should serialize to JSON with ISO8601 date format', () {
      // Arrange
      final now = DateTime.utc(2025, 1, 15, 14, 30, 45, 123); // Use UTC
      final profile = Profile(
        userId: const UserId('test-uuid-123'),
        nickname: 'testuser',
        avatarUrl: 'https://example.com/avatar.jpg',
        updatedAt: now,
      );

      // Act
      final json = profile.toJson();

      // Assert
      expect(json, isA<Map<String, dynamic>>());
      expect(json['userId'], equals('test-uuid-123'));
      expect(json['nickname'], equals('testuser'));
      expect(json['avatarUrl'], equals('https://example.com/avatar.jpg'));
      expect(json['updatedAt'], equals('2025-01-15T14:30:45.123Z'));
    });

    test('should deserialize from JSON with ISO8601 date format', () {
      // Arrange
      final json = {
        'userId': 'test-uuid-456',
        'nickname': 'anotheruser',
        'avatarUrl': null,
        'updatedAt': '2025-01-15T14:30:45.123Z',
      };

      // Act
      final profile = Profile.fromJson(json);

      // Assert
      expect(profile.userId.value, equals('test-uuid-456'));
      expect(profile.nickname, equals('anotheruser'));
      expect(profile.avatarUrl, isNull);
      expect(profile.updatedAt, equals(DateTime.utc(2025, 1, 15, 14, 30, 45, 123)));
    });

    test('should handle null avatarUrl in JSON', () {
      // Arrange
      final json = {
        'userId': 'test-uuid-789',
        'nickname': 'userwithoutavatar',
        'avatarUrl': null,
        'updatedAt': '2025-01-15T14:30:45.123Z',
      };

      // Act
      final profile = Profile.fromJson(json);

      // Assert
      expect(profile.avatarUrl, isNull);
    });

    test('should round-trip JSON serialization correctly', () {
      // Arrange
      final originalProfile = Profile(
        userId: UserId('roundtrip-uuid'),
        nickname: 'roundtripuser',
        avatarUrl: 'https://example.com/roundtrip.jpg',
        updatedAt: DateTime.utc(2025, 1, 15, 14, 30, 45, 123), // Use UTC
      );

      // Act
      final json = originalProfile.toJson();
      final deserializedProfile = Profile.fromJson(json);

      // Assert
      expect(deserializedProfile.userId.value, equals(originalProfile.userId.value));
      expect(deserializedProfile.nickname, equals(originalProfile.nickname));
      expect(deserializedProfile.avatarUrl, equals(originalProfile.avatarUrl));
      expect(deserializedProfile.updatedAt, equals(originalProfile.updatedAt));
    });
  });
}
