import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/features/auth/domain/entities/user.dart';

abstract class AuthRepository {
  Future<Either<Failure, User>> signUp({
    required String email,
    required String password,
    required String nickname,
  });

  Future<Either<Failure, User>> signIn({
    required String email,
    required String password,
  });

  Future<Either<Failure, void>> signOut();

  Future<Either<Failure, User?>> getCurrentUser();
}
