import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/features/auth/domain/entities/user.dart';
import 'package:moonbase_skeleton/features/auth/domain/repositories/auth_repository.dart';
import 'package:moonbase_skeleton/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:moonbase_skeleton/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:moonbase_skeleton/features/auth/data/models/user_model.dart';
import 'package:moonbase_skeleton/core/error_mapper.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required this.local, this.remote});

  final AuthLocalDataSource local;
  final AuthRemoteDataSource? remote; // optional for now

@override
Future<Either<Failure, User>> signIn({required String nickname}) =>
  guard(() async {
    // example local-first sign-in
    final userModel = UserModel(id: '550e8400-e29b-41d4-a716-446655440000', nickname: nickname);
    await local.writeCurrentUser(userModel);
    return userModel.toEntity();
  });

@override
@override
Future<Either<Failure, void>> signOut() =>
  guardVoid(() async {
    await local.clear();
  });


@override
Future<Either<Failure, User?>> getCurrentUser() =>
  guard(() async {
    final m = await local.readCurrentUser();
    return m?.toEntity();
  });
}
