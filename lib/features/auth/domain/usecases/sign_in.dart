import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/features/auth/domain/entities/user.dart';
import 'package:moonbase_skeleton/features/auth/domain/repositories/auth_repository.dart';

class SignInParams {
  const SignInParams(this.nickname);
  
  final String nickname;
}

class SignIn implements UseCase<User, SignInParams> {
  const SignIn(this.repo);

  final AuthRepository repo;

  @override
  Future<Either<Failure, User>> call(SignInParams p) =>
      repo.signIn(nickname: p.nickname);
}
