import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/features/auth/domain/entities/user.dart';
import 'package:moonbase_skeleton/features/auth/domain/repositories/auth_repository.dart';
import 'package:moonbase_skeleton/core/validators.dart';

class SignInParams {
  const SignInParams(this.nickname);
  
  final String nickname;
}

class SignIn implements UseCase<User, SignInParams> {
  const SignIn(this.repo);

  final AuthRepository repo;

  @override
  Future<Either<Failure, User>> call(SignInParams p) {
    final nick = p.nickname.trim();
    if (!isValidNickname(nick)) {
      return Future.value(const Left(ValidationFailure('Nickname must be 1–24 chars (letters, numbers, space, _ . -).')));
    }
    return repo.signIn(nickname: nick);
  }
}
