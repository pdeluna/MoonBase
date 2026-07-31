import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/bases/domain/usecases/join_base.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import '../../../../test_utils/mocks_bases.dart';

void main() {
  setUpAll(() {
    registerFallbackValue('u1'.uid);
  });

  test('JoinBase calls repo.joinBase and returns Right(Base)', () async {
    final repo = MockBaseRepository();
    final usecase = JoinBase(repo);

    when(() => repo.joinBase(inviteCode: any(named: 'inviteCode'), userId: any(named: 'userId')))
      .thenAnswer((_) async => Right(Base(id: 'b2'.bid, name: 'Friends', ownerUserId: 'u9'.uid, createdAt: DateTime(2025, 1, 2))));

    final res = await usecase(
      JoinBaseParams(inviteCode: 'ABCD23', userId: 'u1'.uid),
    );

    expect(res, isA<Right<Failure, Base>>());
    res.match((_) => fail('expected Right'), (b) {
      expect(b.id, 'b2'.bid);
      expect(b.name, 'Friends');
    });

    verify(() => repo.joinBase(inviteCode: 'ABCD23', userId: 'u1'.uid))
        .called(1);
    verifyNoMoreInteractions(repo);
  });

  test('JoinBase returns ValidationFailure for bad code', () async {
    final repo = MockBaseRepository();
    final uc = JoinBase(repo);
    final res = await uc(JoinBaseParams(inviteCode: 'bad!', userId: 'u1'.uid));
    expect(res, isA<Left<Failure, Base>>());
    final f = (res as Left<Failure, Base>).value;
    expect(f, isA<ValidationFailure>());
    verifyZeroInteractions(repo); // never hits repo on invalid input
  });
}
