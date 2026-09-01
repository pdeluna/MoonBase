import 'dart:async';
import 'dart:developer' as developer;

import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/error_mapper.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:moonbase_skeleton/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:moonbase_skeleton/features/auth/domain/entities/user.dart';
import 'package:moonbase_skeleton/features/auth/domain/repositories/auth_repository.dart';
import 'package:moonbase_skeleton/features/profile/data/datasources/profile_local_data_source.dart';

/// dart:developer severity; 1000 matches package:logging `Level.SEVERE`.
const _kReadProfileFailureLevel = 1000;

/// Owner auth: Firebase remote is source of truth; local cache mirrors session.
///
/// After a successful auth write, invokes [profiles].readProfile(uid) so
/// [ProfileFirestoreDataSource] can create-or-return the cloud profile doc.
/// This repository does not construct or write profile field maps itself.
///
/// Profile I/O must not fail the session. [getCurrentUser] returns the Auth
/// user without awaiting [readProfile]. [signIn] / [signUp] still await the
/// create-or-return attempt but catch failures and return [Right].
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required this.local,
    required this.remote,
    required this.profiles,
  });

  final AuthLocalDataSource local;
  final AuthRemoteDataSource remote;
  final ProfileLocalDataSource profiles;

  @override
  Future<Either<Failure, User>> signUp({
    required String email,
    required String password,
    required String nickname,
  }) =>
      guard(() async {
        final model = await remote.signUp(
          email: email,
          password: password,
          nickname: nickname,
        );
        await local.writeCurrentUser(model);
        await _readProfileBestEffort(model.id, during: 'sign-up');
        return model.toEntity();
      });

  @override
  Future<Either<Failure, User>> signIn({
    required String email,
    required String password,
  }) =>
      guard(() async {
        final model = await remote.signIn(email: email, password: password);
        await local.writeCurrentUser(model);
        await _readProfileBestEffort(model.id, during: 'sign-in');
        return model.toEntity();
      });

  @override
  Future<Either<Failure, void>> signOut() => guardVoid(() async {
        await remote.signOut();
        await local.clear();
      });

  @override
  Future<Either<Failure, User?>> getCurrentUser() => guard(() async {
        final model = await remote.getCurrentUser();
        if (model == null) {
          await local.clear();
          return null;
        }
        await local.writeCurrentUser(model);
        // Create-or-return is a side effect, not a session dependency.
        // Do not await: splash / AuthController.data(User) must not wait on
        // profile I/O (blackhole cold-profile is 10–15s). R3 Pass 2 bounds
        // the read inside [_readProfileBestEffort]; this call stays
        // unawaited so that bound cannot rejoin the startup path.
        unawaited(_readProfileBestEffort(model.id, during: 'session restore'));
        return model.toEntity();
      });

  Future<void> _readProfileBestEffort(
    String uid, {
    required String during,
  }) async {
    try {
      final profile = await guardWithTimeout(() => profiles.readProfile(uid));
      profile.match((failure) => throw failure, (_) {});
    } catch (e, st) {
      _logReadProfileFailure(
          uid: uid, during: during, error: e, stackTrace: st);
    }
  }

  void _logReadProfileFailure({
    required String uid,
    required String during,
    required Object error,
    required StackTrace stackTrace,
  }) {
    developer.log(
      'readProfile failed during $during uid=$uid',
      name: 'AuthRepository',
      level: _kReadProfileFailureLevel,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
