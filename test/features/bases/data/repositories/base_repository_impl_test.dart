import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/bases/data/datasources/base_local_data_source_impl.dart';
import 'package:moonbase_skeleton/features/bases/data/repositories/base_repository_impl.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';

void main() {
  group('BaseRepositoryImpl + InMemory DS', () {
    late InMemoryBaseLocalDataSource ds;
    late BaseRepositoryImpl repo;

    setUp(() {
      ds = InMemoryBaseLocalDataSource();
      repo = BaseRepositoryImpl(local: ds);
    });

    test('createBase then listBases includes the created base for owner', () async {
      final created = await repo.createBase(name: 'Home', ownerUserId: 'u1'.uid.value);
      expect(created, isA<Right<Failure, Base>>());
      final base = (created as Right<Failure, Base>).value;

      final listRes = await repo.listBases(userId: 'u1'.uid.value);
      expect(listRes, isA<Right<Failure, List<Base>>>());

      final list = (listRes as Right<Failure, List<Base>>).value;
      expect(list.length, 1);
      expect(list.first.id, base.id);
      expect(list.first.name, 'Home');
    });

    test('generateInviteCode -> joinBase -> member sees base in list', () async {
      final created = await repo.createBase(name: 'Friends', ownerUserId: 'u9'.uid.value);
      final base = (created as Right<Failure, Base>).value;

      final codeRes = await repo.generateInviteCode(baseId: base.id.value, requesterUserId: 'u9'.uid.value);
      expect(codeRes, isA<Right<Failure, String>>());
      final code = (codeRes as Right<Failure, String>).value;

      final joinRes = await repo.joinBase(inviteCode: code, userId: 'u2'.uid.value);
      expect(joinRes, isA<Right<Failure, Base>>());

      final listRes = await repo.listBases(userId: 'u2'.uid.value);
      final list = (listRes as Right<Failure, List<Base>>).value;
      expect(list.length, 1);
      expect(list.first.id, base.id);
    });

    test('renameBase updates name; deleteBase removes it', () async {
      final created = await repo.createBase(name: 'Temp', ownerUserId: 'u1'.uid.value);
      final base = (created as Right<Failure, Base>).value;

      final rn = await repo.renameBase(baseId: base.id.value, newName: 'Renamed', requesterUserId: 'u1'.uid.value);
      expect(rn, isA<Right<Failure, void>>());

      final afterRename = (await repo.listBases(userId: 'u1'.uid.value) as Right<Failure, List<Base>>).value;
      expect(afterRename.single.name, 'Renamed');

      final del = await repo.deleteBase(baseId: base.id.value, requesterUserId: 'u1'.uid.value);
      expect(del, isA<Right<Failure, void>>());

      final afterDelete = (await repo.listBases(userId: 'u1'.uid.value) as Right<Failure, List<Base>>).value;
      expect(afterDelete, isEmpty);
    });

    test('joinBase with invalid code returns Left(CacheFailure)', () async {
      final res = await repo.joinBase(inviteCode: 'BAD123', userId: 'u1'.uid.value);
      expect(res, isA<Left<Failure, Base>>());
      final failure = (res as Left<Failure, Base>).value;
      expect(failure, isA<CacheFailure>());
    });
  });
}
