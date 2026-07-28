import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';

void main() {
  group('Base entity', () {
    final createdAt = DateTime.utc(2024, 1, 1);

    Base build({
      String id = 'test-id',
      String name = 'Test Base',
      String owner = 'owner-id',
      DateTime? at,
    }) =>
        Base(
          id: id.bid,
          name: name,
          ownerUserId: owner.uid,
          createdAt: at ?? createdAt,
        );

    test('creates with required fields', () {
      final base = build();

      expect(base.id, 'test-id'.bid);
      expect(base.name, 'Test Base');
      expect(base.ownerUserId, 'owner-id'.uid);
      expect(base.createdAt, createdAt);
    });

    test('copyWith updates name and preserves identity fields', () {
      final original = build();
      final updated = original.copyWith(name: 'Updated Base');

      expect(updated.id, original.id);
      expect(updated.name, 'Updated Base');
      expect(updated.ownerUserId, original.ownerUserId);
      expect(updated.createdAt, original.createdAt);
    });

    test('copyWith with null name keeps original name', () {
      final original = build();
      final updated = original.copyWith();

      expect(updated.name, original.name);
      expect(updated, original);
    });

    test('equality is by all fields, not id alone', () {
      final a = build();
      final sameIdDifferentName = build(name: 'Different');
      final identical = build();
      final differentId = build(id: 'other-id');

      expect(a, identical);
      expect(a, isNot(sameIdDifferentName));
      expect(a, isNot(differentId));
    });

    test('hashCode matches for equal instances', () {
      expect(build().hashCode, build().hashCode);
    });
  });
}
