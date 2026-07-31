import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/error_mapper.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:moonbase_skeleton/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:moonbase_skeleton/features/auth/domain/entities/user.dart';
import 'package:moonbase_skeleton/features/auth/domain/repositories/auth_repository.dart';
import 'package:moonbase_skeleton/features/profile/data/datasources/profile_local_data_source.dart';

/// Owner auth: Firebase remote is source of truth; local cache mirrors session.
///
/// After a successful auth write, invokes [profiles].readProfile(uid) so
/// [ProfileFirestoreDataSource] can create-or-return the cloud profile doc.
/// This repository does not construct or write profile field maps itself.
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
        await profiles.readProfile(model.id);
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
        await profiles.readProfile(model.id);
        return model.toEntity();
      });

  @override
  Future<Either<Failure, void>> signOut() =>
      guardVoid(() async {
        await remote.signOut();
        await local.clear();
      });

  @override
  Future<Either<Failure, User?>> getCurrentUser() =>
      guard(() async {
        final model = await remote.getCurrentUser();
        if (model == null) {
          await local.clear();
          return null;
        }
        await local.writeCurrentUser(model);
        await profiles.readProfile(model.id);
        return model.toEntity();
      });
}
