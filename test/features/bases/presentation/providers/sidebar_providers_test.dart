import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/bases/presentation/providers/sidebar_providers.dart';

void main() {
  group('effectiveSelectedBaseProvider', () {
    final base1 = Base(
      id: '1'.bid,
      name: 'Base 1',
      ownerUserId: 'user1'.uid,
      createdAt: DateTime.utc(2024, 1, 1),
    );
    final base2 = Base(
      id: '2'.bid,
      name: 'Base 2',
      ownerUserId: 'user1'.uid,
      createdAt: DateTime.utc(2024, 2, 1),
    );
    final foreignBase = Base(
      id: '9'.bid,
      name: 'Other User Base',
      ownerUserId: 'user2'.uid,
      createdAt: DateTime.utc(2024, 3, 1),
    );

    Future<ProviderContainer> containerWith({
      Base? selected,
      Base? lastAccessed,
      List<Base> userBases = const [],
    }) async {
      final container = ProviderContainer(
        overrides: [
          selectedBaseProvider.overrideWith((ref) => selected),
          lastAccessedBaseProvider.overrideWith((ref) async => lastAccessed),
          basesListProvider.overrideWith((ref) async => userBases),
        ],
      );
      addTearDown(container.dispose);

      await container.read(lastAccessedBaseProvider.future);
      await container.read(basesListProvider.future);
      return container;
    }

    test('returns explicit selection when selectedBase is set', () async {
      final container = await containerWith(
        selected: base1,
        lastAccessed: base2,
        userBases: [base1, base2],
      );

      expect(container.read(effectiveSelectedBaseProvider), base1);
    });

    test('falls back to last-accessed when it belongs to the user', () async {
      final container = await containerWith(
        selected: null,
        lastAccessed: base2,
        userBases: [base1, base2],
      );

      expect(container.read(effectiveSelectedBaseProvider), base2);
    });

    test('ignores selected base that is not in the user list', () async {
      final container = await containerWith(
        selected: foreignBase,
        lastAccessed: base2,
        userBases: [base1, base2],
      );

      expect(container.read(effectiveSelectedBaseProvider), base2);
    });

    test('returns null when last-accessed is not in the user base list',
        () async {
      final container = await containerWith(
        selected: null,
        lastAccessed: foreignBase,
        userBases: [base1, base2],
      );

      expect(container.read(effectiveSelectedBaseProvider), isNull);
    });

    test('returns null when nothing is selected and no last-accessed',
        () async {
      final container = await containerWith(
        selected: null,
        lastAccessed: null,
        userBases: [base1],
      );

      expect(container.read(effectiveSelectedBaseProvider), isNull);
    });

    test('returns null for empty user list even if last-accessed exists',
        () async {
      final container = await containerWith(
        selected: null,
        lastAccessed: base1,
        userBases: const [],
      );

      expect(container.read(effectiveSelectedBaseProvider), isNull);
    });

    test('prefers selection over last-accessed for a single base', () async {
      final container = await containerWith(
        selected: base1,
        lastAccessed: base1,
        userBases: [base1],
      );

      expect(container.read(effectiveSelectedBaseProvider), base1);
    });
  });
}
