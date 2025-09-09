import '../../../../core/either.dart';
import '../../../../core/failure.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthLocalDataSource local;
  final AuthRemoteDataSource? remote; // optional for now

  AuthRepositoryImpl({required this.local, this.remote});

  @override
  Future<Either<Failure, User>> signIn({required String nickname}) async {
    // STEP 1 (later): local-first sign-in (uuid + persist), or remote if provided.
    // For now, leave a stub so compile succeeds.
    return const Left(UnknownFailure('Not implemented'));
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    return const Left(UnknownFailure('Not implemented'));
  }

  @override
  Future<Either<Failure, User?>> getCurrentUser() async {
    // Safe default for initial wiring
    final UserModel? stored = await local.readCurrentUser();
    return Right(stored?.toEntity());
  }
}
