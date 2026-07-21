import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/features/auth/data/datasources/auth_local_data_source_impl.dart';
import 'package:moonbase_skeleton/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:moonbase_skeleton/features/auth/data/models/user_model.dart';
import 'package:moonbase_skeleton/features/auth/data/repositories/auth_repository_impl.dart';

class _MockRemote extends Mock implements AuthRemoteDataSource {}

void main() {
  late SharedPreferences prefs;
  late AuthLocalDataSourceImpl local;
  late _MockRemote remote;
  late AuthRepositoryImpl repo;

  const model = UserModel(id: 'firebase-uid-1', nickname: 'owner');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    local = AuthLocalDataSourceImpl(prefs);
    remote = _MockRemote();
    repo = AuthRepositoryImpl(local: local, remote: remote);
  });

  test('signIn writes remote user into local cache', () async {
    when(() => remote.signIn(
          email: 'owner@example.com',
          password: 'secret1',
        )).thenAnswer((_) async => model);

    final result = await repo.signIn(
      email: 'owner@example.com',
      password: 'secret1',
    );

    expect(result, isA<Right<Failure, dynamic>>());
    final cached = await local.readCurrentUser();
    expect(cached?.id, 'firebase-uid-1');
    expect(cached?.nickname, 'owner');
  });

  test('getCurrentUser syncs remote session into local', () async {
    when(() => remote.getCurrentUser()).thenAnswer((_) async => model);

    final result = await repo.getCurrentUser();

    expect(result, isA<Right<Failure, dynamic>>());
    result.match(
      (_) => fail('expected user'),
      (user) {
        expect(user?.id.value, 'firebase-uid-1');
        expect(user?.nickname, 'owner');
      },
    );
    final cached = await local.readCurrentUser();
    expect(cached?.id, 'firebase-uid-1');
  });

  test('getCurrentUser clears local when remote session is null', () async {
    await local.writeCurrentUser(model);
    when(() => remote.getCurrentUser()).thenAnswer((_) async => null);

    final result = await repo.getCurrentUser();

    expect(result, isA<Right<Failure, dynamic>>());
    result.match(
      (_) => fail('expected null user'),
      (user) => expect(user, isNull),
    );
    expect(await local.readCurrentUser(), isNull);
  });

  test('signOut clears remote and local', () async {
    await local.writeCurrentUser(model);
    when(() => remote.signOut()).thenAnswer((_) async {});

    final result = await repo.signOut();

    expect(result, isA<Right<Failure, void>>());
    verify(() => remote.signOut()).called(1);
    expect(await local.readCurrentUser(), isNull);
  });
}
