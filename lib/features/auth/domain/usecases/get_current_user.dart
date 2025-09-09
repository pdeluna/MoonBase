import '../../../../core/either.dart';
import '../../../../core/failure.dart';
import '../../../../core/usecase.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class GetCurrentUser implements UseCase<User?, NoParams> {
  final AuthRepository repo;
  const GetCurrentUser(this.repo);

  @override
  Future<Either<Failure, User?>> call(NoParams _) => repo.getCurrentUser();
}
