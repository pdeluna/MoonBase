import 'package:cloud_firestore/cloud_firestore.dart';
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
          memberUids: const ['owner-id'],
        );

    test('round-trips map serialization', () {
      final original = build();
      final restored = BaseModel.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.ownerUserId, original.ownerUserId);
      expect(restored.createdAt.toUtc(), original.createdAt.toUtc());
      expect(restored.memberUids, original.memberUids);
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

  group('BaseModel Firestore codec', () {
    test('toFirestore emits exactly schema keys with Timestamp createdAt', () {
      final created = DateTime.utc(2024, 6, 1, 12);
      final model = BaseModel(
        id: 'base_1',
        name: 'Family',
        ownerUserId: 'uid_alice',
        createdAt: created,
        memberUids: const ['uid_alice', 'uid_bob'],
      );

      final map = model.toFirestore();
      expect(
        map.keys.toSet(),
        {'name', 'ownerUid', 'memberUids', 'createdAt', 'schemaVersion'},
      );
      expect(map['name'], 'Family');
      expect(map['ownerUid'], 'uid_alice');
      expect(map['memberUids'], ['uid_alice', 'uid_bob']);
      expect(map['schemaVersion'], 1);
      expect(map['createdAt'], isA<Timestamp>());
      expect(map.containsKey('id'), isFalse);
      expect(map.containsKey('ownerUserId'), isFalse);
    });

    test('fromFirestore maps doc id and ownerUid', () {
      final created = DateTime.utc(2024, 6, 1, 12);
      final model = BaseModel.fromFirestore('base_1', {
        'name': 'Family',
        'ownerUid': 'uid_alice',
        'memberUids': ['uid_alice'],
        'createdAt': Timestamp.fromDate(created),
        'schemaVersion': 1,
      });

      expect(model.id, 'base_1');
      expect(model.name, 'Family');
      expect(model.ownerUserId, 'uid_alice');
      expect(model.memberUids, ['uid_alice']);
      expect(model.createdAt, created);
    });
  });
}
