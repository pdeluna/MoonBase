import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/presentation/failure_presenter.dart';
import 'package:moonbase_skeleton/features/auth/presentation/providers/current_user_id_provider.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/bases/presentation/providers/base_providers.dart';
import 'package:moonbase_skeleton/features/bases/presentation/providers/sidebar_providers.dart';

import '../../../../test_utils/mocks_bases.dart';

void main() {
  setUpAll(registerBasesFallbacks);

  group('basesListProvider failure surface', () {
    test('Left(Failure) is rethrown as the Failure itself, not an Exception',
        () async {
      final repo = MockBaseRepository();
      when(() => repo.listBases(userId: any(named: 'userId'))).thenAnswer(
        (_) async => const Left<Failure, List<Base>>(
          NetworkFailure('retry-limit-exceeded'),
        ),
      );
      final container = ProviderContainer(overrides: [
        baseRepositoryProvider.overrideWithValue(repo),
        currentUserIdProvider.overrideWithValue('user1'),
      ]);
      addTearDown(container.dispose);

      await expectLater(
        container.read(basesListProvider.future),
        throwsA(isA<NetworkFailure>()),
      );
      final state = container.read(basesListProvider);
      expect(state.error, isA<NetworkFailure>());
      expect(state.error, isNot(isA<Exception>()));
    });

    test('signed-out read is an UnauthenticatedFailure', () async {
      final container = ProviderContainer(overrides: [
        currentUserIdProvider.overrideWithValue(null),
      ]);
      addTearDown(container.dispose);

      await expectLater(
        container.read(basesListProvider.future),
        throwsA(isA<UnauthenticatedFailure>()),
      );
    });

    test('sidebarVm carries the Failure and plain user copy on error',
        () async {
      const failure = NetworkTimeoutFailure();
      final container = ProviderContainer(overrides: [
        basesListProvider.overrideWith((ref) async => throw failure),
        lastAccessedBaseProvider.overrideWith((ref) async => null),
        selectedBaseProvider.overrideWith((ref) => null),
      ]);
      addTearDown(container.dispose);

      await expectLater(
        container.read(basesListProvider.future),
        throwsA(isA<NetworkTimeoutFailure>()),
      );
      final vm = container.read(sidebarVmProvider);
      expect(vm.hasError, isTrue);
      expect(vm.error, same(failure));
      expect(vm.errorMessage, kNetworkTimeoutCopy);
      expect(vm.errorMessage, isNot(contains('NetworkTimeoutFailure')));
    });
  });

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
