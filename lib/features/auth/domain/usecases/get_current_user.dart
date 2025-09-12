import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/features/auth/domain/entities/user.dart';
import 'package:moonbase_skeleton/features/auth/domain/repositories/auth_repository.dart';

class GetCurrentUser implements UseCase<User?, NoParams> {
  const GetCurrentUser(this.repo);

  final AuthRepository repo;

  @override
  Future<Either<Failure, User?>> call(NoParams _) => repo.getCurrentUser();
}
