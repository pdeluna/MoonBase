import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/features/bases/data/datasources/base_local_data_source_impl.dart';
import 'package:moonbase_skeleton/features/bases/data/repositories/base_repository_impl.dart';
import 'package:moonbase_skeleton/features/bases/domain/usecases/create_base.dart';
import 'package:moonbase_skeleton/features/bases/domain/usecases/join_base.dart';
import 'package:moonbase_skeleton/features/bases/domain/usecases/list_bases.dart';
import 'package:moonbase_skeleton/features/bases/presentation/controllers/base_controller.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/core/ids.dart';

void main() {
  group('BaseController (with real repo + in-memory DS)', () {
    late InMemoryBaseLocalDataSource ds;
    late BaseRepositoryImpl repo;
    late ListBases listBases;
    late CreateBase createBase;
    late JoinBase joinBase;
    late BaseController c;

    setUp(() {
      ds = InMemoryBaseLocalDataSource();
      repo = BaseRepositoryImpl(local: ds);
      listBases = ListBases(repo);
      createBase = CreateBase(repo);
      joinBase = JoinBase(repo);
      c = BaseController(listBases, createBase, joinBase);
    });

    test('load shows empty initially, then creates and lists one base', () async {
      await c.load('u1');
      c.state.bases.maybeWhen(
        data: (list) => expect(list, isEmpty),
        orElse: () => fail('expected data []'),
      );

      await c.create('Home', 'u1');
      // create() triggers load() on success; wait for it to complete
      while (c.state.bases.isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      c.state.bases.maybeWhen(
        data: (list) {
          expect(list.length, 1);
          expect(list.first.name, 'Home');
        },
        orElse: () => fail('expected data with one base'),
      );
    });

    test('join adds base to another user via invite code', () async {
      // owner creates a base
      final created = await repo.createBase(name: 'Friends', ownerUserId: 'u9') as Right<dynamic, Base>;
      final base = created.value;
      final code = (await repo.generateInviteCode(baseId: base.id.value, requesterUserId: 'u9'.uid.value) as Right<dynamic, String>).value;

      await c.load('u2');
      c.state.bases.maybeWhen(data: (l) => expect(l, isEmpty), orElse: () => fail('expected empty'));

      await c.join(code, 'u2');
      await c.load('u2');
      c.state.bases.maybeWhen(
        data: (list) {
          expect(list.length, 1);
          expect(list.single.id, base.id);
        },
        orElse: () => fail('expected data with joined base'),
      );
    });
  });
}
