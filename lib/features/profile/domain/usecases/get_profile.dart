import '../../../../core/either.dart';
import '../../../../core/failure.dart';
import '../../../../core/usecase.dart';
import '../entities/profile.dart';
import '../repositories/profile_repository.dart';

class GetProfileParams {
  final String userId;
  const GetProfileParams(this.userId);
}

class GetProfile implements UseCase<Profile?, GetProfileParams> {
  final ProfileRepository repo;
  const GetProfile(this.repo);

  @override
  Future<Either<Failure, Profile?>> call(GetProfileParams p) async {
    try {
      return await repo.getProfile(p.userId);
    } catch (e) {
      return Left(UnknownFailure('Get profile failed: ${e.toString()}'));
    }
  }
}
