import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/core/validators.dart';
import 'package:moonbase_skeleton/features/auth/domain/entities/user.dart';
import 'package:moonbase_skeleton/features/auth/domain/repositories/auth_repository.dart';

class SignUpParams {
  const SignUpParams({required this.email, required this.password});

  final String email;
  final String password;
}

class SignUp implements UseCase<User, SignUpParams> {
  const SignUp(this.repo);

  final AuthRepository repo;

  @override
  Future<Either<Failure, User>> call(SignUpParams p) {
    final email = p.email.trim();
    if (!isValidEmail(email)) {
      return Future.value(
        const Left(ValidationFailure('Enter a valid email address.')),
      );
    }
    if (!isValidPassword(p.password)) {
      return Future.value(
        const Left(ValidationFailure('Password must be at least 6 characters.')),
      );
    }
    return repo.signUp(email: email, password: p.password);
  }
}
