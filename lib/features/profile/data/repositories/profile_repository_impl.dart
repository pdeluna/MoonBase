import '../../../../core/either.dart';
import '../../../../core/failure.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_local_data_source.dart';
import '../datasources/profile_remote_data_source.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileLocalDataSource local;
  final ProfileRemoteDataSource? remote;

  ProfileRepositoryImpl({required this.local, this.remote});

  @override
  Future<Either<Failure, Profile?>> getProfile(String userId) async {
    // Safe default while wiring: local-first read
    final model = await local.readProfile(userId);
    return Right(model?.toEntity());
  }

  @override
  Future<Either<Failure, Profile>> updateProfile({
    required String userId,
    String? nickname,
    String? avatarUrl,
  }) async {
    return const Left(UnknownFailure('Not implemented'));
  }
}
