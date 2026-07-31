import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/features/auth/data/datasources/auth_local_data_source_impl.dart';
import 'package:moonbase_skeleton/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:moonbase_skeleton/features/auth/data/models/user_model.dart';
import 'package:moonbase_skeleton/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:moonbase_skeleton/features/profile/data/datasources/profile_local_data_source.dart';
import 'package:moonbase_skeleton/features/profile/data/models/profile_model.dart';

class _MockRemote extends Mock implements AuthRemoteDataSource {}

class _MockProfiles extends Mock implements ProfileLocalDataSource {}

void main() {
  late SharedPreferences prefs;
  late AuthLocalDataSourceImpl local;
  late _MockRemote remote;
  late _MockProfiles profiles;
  late AuthRepositoryImpl repo;

  const model = UserModel(id: 'firebase-uid-1', nickname: 'owner');

  setUpAll(() {
    registerFallbackValue(
      ProfileModel(
        userId: 'fallback',
        nickname: 'fallback',
        updatedAt: DateTime.utc(2020),
      ),
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    local = AuthLocalDataSourceImpl(prefs);
    remote = _MockRemote();
    profiles = _MockProfiles();
    when(() => profiles.readProfile(any())).thenAnswer((invocation) async {
      final id = invocation.positionalArguments.first as String;
      return ProfileModel(
        userId: id,
        nickname: 'owner',
        updatedAt: DateTime.utc(2024),
        themeMode: 'light',
        createdAt: DateTime.utc(2024),
      );
    });
    repo = AuthRepositoryImpl(local: local, remote: remote, profiles: profiles);
  });

  test('signUp writes remote user into local cache and ensures profile read', () async {
    when(() => remote.signUp(
          email: 'owner@example.com',
          password: 'secret1',
          nickname: 'MoonOwner',
        )).thenAnswer((_) async => const UserModel(
          id: 'firebase-uid-2',
          nickname: 'MoonOwner',
        ));

    final result = await repo.signUp(
      email: 'owner@example.com',
      password: 'secret1',
      nickname: 'MoonOwner',
    );

    expect(result, isA<Right<Failure, dynamic>>());
    final cached = await local.readCurrentUser();
    expect(cached?.id, 'firebase-uid-2');
    expect(cached?.nickname, 'MoonOwner');
    verify(() => profiles.readProfile('firebase-uid-2')).called(1);
  });

  test('signIn writes remote user into local cache and ensures profile read', () async {
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
    verify(() => profiles.readProfile('firebase-uid-1')).called(1);
  });

  test('getCurrentUser syncs remote session into local and ensures profile read', () async {
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
    verify(() => profiles.readProfile('firebase-uid-1')).called(1);
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
    verifyNever(() => profiles.readProfile(any()));
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
