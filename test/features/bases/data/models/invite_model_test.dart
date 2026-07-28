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
  });
}
