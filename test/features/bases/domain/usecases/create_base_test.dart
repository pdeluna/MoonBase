import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/bases/domain/usecases/create_base.dart';

import '../../../../test_utils/mocks_bases.dart';

void main() {
  test('CreateBase calls repo.createBase and returns Right(Base)', () async {
    final repo = MockBaseRepository();
    final usecase = CreateBase(repo);

    when(() => repo.createBase(name: any(named: 'name'), ownerUserId: any(named: 'ownerUserId')))
      .thenAnswer((_) async => Right(Base(id: 'b1', name: 'Home', ownerUserId: 'u1', createdAt: DateTime(2025, 1, 1))));

    final res = await usecase(const CreateBaseParams(name: 'Home', ownerUserId: 'u1'));

    expect(res, isA<Right<Failure, Base>>());
    res.match((_) => fail('expected Right'), (b) {
      expect(b.id, 'b1');
      expect(b.name, 'Home');
      expect(b.ownerUserId, 'u1');
    });

    verify(() => repo.createBase(name: 'Home', ownerUserId: 'u1')).called(1);
    verifyNoMoreInteractions(repo);
  });
}
