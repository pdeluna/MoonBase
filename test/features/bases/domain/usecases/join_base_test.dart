import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/bases/domain/usecases/join_base.dart';

import '../../../../test_utils/mocks_bases.dart';

void main() {
  test('JoinBase calls repo.joinBase and returns Right(Base)', () async {
    final repo = MockBaseRepository();
    final usecase = JoinBase(repo);

    when(() => repo.joinBase(inviteCode: any(named: 'inviteCode'), userId: any(named: 'userId')))
      .thenAnswer((_) async => Right(Base(id: 'b2', name: 'Friends', ownerUserId: 'u9', createdAt: DateTime(2025, 1, 2))));

    final res = await usecase(const JoinBaseParams(inviteCode: 'ABC123', userId: 'u1'));

    expect(res, isA<Right<Failure, Base>>());
    res.match((_) => fail('expected Right'), (b) {
      expect(b.id, 'b2');
      expect(b.name, 'Friends');
    });

    verify(() => repo.joinBase(inviteCode: 'ABC123', userId: 'u1')).called(1);
    verifyNoMoreInteractions(repo);
  });
}
