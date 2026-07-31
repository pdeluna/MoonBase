import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/features/bases/data/models/invite_model.dart';

void main() {
  group('InviteModel', () {
    final createdAt = DateTime.utc(2024, 1, 1);
    final expiresAt = DateTime.utc(2024, 2, 1);

    InviteModel build() => InviteModel(
          id: 'invite_123',
          baseId: 'base_123',
          code: 'TEST123',
          createdByUserId: 'user_123',
          createdAt: createdAt,
          expiresAt: expiresAt,
          maxUses: 5,
          usedCount: 1,
        );

    test('round-trips map serialization', () {
      final original = build();
      final restored = InviteModel.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.baseId, original.baseId);
      expect(restored.code, original.code);
      expect(restored.createdByUserId, original.createdByUserId);
      expect(restored.createdAt.toUtc(), original.createdAt.toUtc());
      expect(restored.expiresAt!.toUtc(), original.expiresAt!.toUtc());
      expect(restored.maxUses, original.maxUses);
      expect(restored.usedCount, original.usedCount);
    });

    test('fromMap handles null expiry and unlimited uses', () {
      final model = InviteModel.fromMap({
        'id': 'invite_123',
        'baseId': 'base_123',
        'code': 'OPEN',
        'createdByUserId': 'user_123',
        'createdAt': '2024-01-01T00:00:00.000Z',
        'expiresAt': null,
        'maxUses': null,
        'usedCount': 0,
      });

      expect(model.expiresAt, isNull);
      expect(model.maxUses, isNull);
      expect(model.usedCount, 0);
    });

    test('fromMap defaults missing usedCount to 0', () {
      final model = InviteModel.fromMap({
        'id': 'invite_123',
        'baseId': 'base_123',
        'code': 'OPEN',
        'createdByUserId': 'user_123',
        'createdAt': '2024-01-01T00:00:00.000Z',
      });

      expect(model.usedCount, 0);
    });

    test('toEntity preserves rule-relevant fields', () {
      final entity = build().toEntity();

      expect(entity.id.value, 'invite_123');
      expect(entity.baseId.value, 'base_123');
      expect(entity.code, 'TEST123');
      expect(entity.maxUses, 5);
      expect(entity.usedCount, 1);
      expect(entity.expiresAt!.toUtc(), expiresAt);
    });

    test('toFirestore emits rule keys only (maps domain names)', () {
      final map = build().toFirestore();

      expect(map.keys.toSet(), {
        'createdBy',
        'createdAt',
        'useCount',
        'maxUses',
        'expiresAt',
        'schemaVersion',
      });
      expect(map.containsKey('createdByUserId'), isFalse);
      expect(map.containsKey('usedCount'), isFalse);
      expect(map.containsKey('code'), isFalse);
      expect(map.containsKey('baseId'), isFalse);
      expect(map['createdBy'], 'user_123');
      expect(map['useCount'], 1);
      expect(map['schemaVersion'], 1);
      expect(map['createdAt'], isA<Timestamp>());
    });

    test('toFirestore omits null maxUses and expiresAt', () {
      final map = InviteModel(
        id: 'ABCDEF',
        baseId: 'base_1',
        code: 'ABCDEF',
        createdByUserId: 'user_123',
        createdAt: createdAt,
      ).toFirestore();

      expect(map.keys.toSet(), {
        'createdBy',
        'createdAt',
        'useCount',
        'schemaVersion',
      });
    });

    test('fromFirestore maps doc id and rule field names', () {
      final model = InviteModel.fromFirestore('base_1', 'ABCDEF', {
        'createdBy': 'user_123',
        'createdAt': Timestamp.fromDate(createdAt),
        'useCount': 2,
        'maxUses': 5,
        'expiresAt': Timestamp.fromDate(expiresAt),
        'schemaVersion': 1,
      });

      expect(model.code, 'ABCDEF');
      expect(model.baseId, 'base_1');
      expect(model.createdByUserId, 'user_123');
      expect(model.usedCount, 2);
      expect(model.maxUses, 5);
    });
  });
}
