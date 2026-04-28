import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/legacy/models/models.dart';

void main() {
  group('Base Model Tests', () {
    test('should create Base with required fields', () {
      final base = Base(
        id: 'test-id',
        name: 'Test Base',
        ownerUserId: 'owner-id',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      expect(base.id, 'test-id');
      expect(base.name, 'Test Base');
      expect(base.ownerUserId, 'owner-id');
      expect(base.description, isNull);
      expect(base.memberIds, isEmpty);
      expect(base.avatarUrl, isNull);
    });

    test('should create Base with all fields', () {
      final base = Base(
        id: 'test-id',
        name: 'Test Base',
        ownerUserId: 'owner-id',
        description: 'A test base',
        memberIds: ['member1', 'member2'],
        avatarUrl: 'https://example.com/avatar.jpg',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      expect(base.description, 'A test base');
      expect(base.memberIds, ['member1', 'member2']);
      expect(base.avatarUrl, 'https://example.com/avatar.jpg');
    });

    test('should serialize and deserialize correctly', () {
      final original = Base(
        id: 'test-id',
        name: 'Test Base',
        ownerUserId: 'owner-id',
        description: 'A test base',
        memberIds: ['member1', 'member2'],
        avatarUrl: 'https://example.com/avatar.jpg',
        createdAt: DateTime(2024, 1, 1, 12, 0, 0),
        updatedAt: DateTime(2024, 1, 1, 12, 0, 0),
      );

      final json = original.toMap();
      final restored = Base.fromMap(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.ownerUserId, original.ownerUserId);
      expect(restored.description, original.description);
      expect(restored.memberIds, original.memberIds);
      expect(restored.avatarUrl, original.avatarUrl);
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
    });

    test('should handle JSON serialization', () {
      final base = Base(
        id: 'test-id',
        name: 'Test Base',
        ownerUserId: 'owner-id',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final jsonString = base.toJson();
      final restored = Base.fromJson(jsonString);

      expect(restored.id, base.id);
      expect(restored.name, base.name);
      expect(restored.ownerUserId, base.ownerUserId);
    });

    test('should handle copyWith correctly', () {
      final original = Base(
        id: 'test-id',
        name: 'Test Base',
        ownerUserId: 'owner-id',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final updated = original.copyWith(
        name: 'Updated Base',
        description: 'Updated description',
        memberIds: ['new-member'],
      );

      expect(updated.id, original.id);
      expect(updated.name, 'Updated Base');
      expect(updated.description, 'Updated description');
      expect(updated.memberIds, ['new-member']);
      expect(updated.ownerUserId, original.ownerUserId);
      expect(updated.createdAt, original.createdAt);
      expect(updated.updatedAt, original.updatedAt);
    });

    test('should handle equality correctly', () {
      final base1 = Base(
        id: 'test-id',
        name: 'Test Base',
        ownerUserId: 'owner-id',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final base2 = Base(
        id: 'test-id',
        name: 'Different Name',
        ownerUserId: 'different-owner',
        createdAt: DateTime(2024, 1, 2),
        updatedAt: DateTime(2024, 1, 2),
      );

      final base3 = Base(
        id: 'different-id',
        name: 'Test Base',
        ownerUserId: 'owner-id',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      expect(base1, equals(base2)); // Same ID
      expect(base1, isNot(equals(base3))); // Different ID
    });

    test('should handle hashCode correctly', () {
      final base1 = Base(
        id: 'test-id',
        name: 'Test Base',
        ownerUserId: 'owner-id',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final base2 = Base(
        id: 'test-id',
        name: 'Different Name',
        ownerUserId: 'different-owner',
        createdAt: DateTime(2024, 1, 2),
        updatedAt: DateTime(2024, 1, 2),
      );

      expect(base1.hashCode, equals(base2.hashCode));
    });

    test('should handle empty memberIds in fromMap', () {
      final map = {
        'id': 'test-id',
        'name': 'Test Base',
        'ownerUserId': 'owner-id',
        'memberIds': null,
        'createdAt': '2024-01-01T00:00:00.000Z',
        'updatedAt': '2024-01-01T00:00:00.000Z',
      };

      final base = Base.fromMap(map);
      expect(base.memberIds, isEmpty);
    });
  });
}
