import '../../../../core/either.dart';
import '../../../../core/failure.dart';
import '../../../../core/usecase.dart';
import '../repositories/auth_repository.dart';

class SignOut implements UseCase<void, NoParams> {
  final AuthRepository repo;
  const SignOut(this.repo);

  @override
  Future<Either<Failure, void>> call(NoParams _) => repo.signOut();
}
