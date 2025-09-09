import '../../../../core/either.dart';
import '../../../../core/failure.dart';
import '../../../../core/usecase.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class SignInParams {
  final String nickname;
  const SignInParams(this.nickname);
}

class SignIn implements UseCase<User, SignInParams> {
  final AuthRepository repo;
  const SignIn(this.repo);

  @override
  Future<Either<Failure, User>> call(SignInParams params) async {
    try {
      return await repo.signIn(nickname: params.nickname);
    } catch (e) {
      return Left(UnknownFailure('Sign in failed: ${e.toString()}'));
    }
  }
}
