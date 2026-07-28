import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/features/bases/data/models/base_model.dart';

void main() {
  group('BaseModel', () {
    final createdAt = DateTime.utc(2024, 1, 1, 12);

    BaseModel build() => BaseModel(
          id: 'test-id',
          name: 'Test Base',
          ownerUserId: 'owner-id',
          createdAt: createdAt,
        );

    test('round-trips map serialization', () {
      final original = build();
      final restored = BaseModel.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.ownerUserId, original.ownerUserId);
      expect(restored.createdAt.toUtc(), original.createdAt.toUtc());
    });

    test('toEntity maps string ids to typed ids', () {
      final entity = build().toEntity();

      expect(entity.id.value, 'test-id');
      expect(entity.name, 'Test Base');
      expect(entity.ownerUserId.value, 'owner-id');
      expect(entity.createdAt.toUtc(), createdAt);
    });

    test('fromMap parses ISO8601 createdAt', () {
      final model = BaseModel.fromMap({
        'id': 'test-id',
        'name': 'Test Base',
        'ownerUserId': 'owner-id',
        'createdAt': '2024-01-01T12:00:00.000Z',
      });

      expect(model.createdAt.toUtc(), createdAt);
    });
  });
}
