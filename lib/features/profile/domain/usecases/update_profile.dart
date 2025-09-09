import '../../../../core/either.dart';
import '../../../../core/failure.dart';
import '../../../../core/usecase.dart';
import '../entities/profile.dart';
import '../repositories/profile_repository.dart';

class UpdateProfileParams {
  final String userId;
  final String? nickname;
  final String? avatarUrl;

  const UpdateProfileParams({
    required this.userId,
    this.nickname,
    this.avatarUrl,
  });
}

class UpdateProfile implements UseCase<Profile, UpdateProfileParams> {
  final ProfileRepository repo;
  const UpdateProfile(this.repo);

  @override
  Future<Either<Failure, Profile>> call(UpdateProfileParams p) async {
    try {
      return await repo.updateProfile(userId: p.userId, nickname: p.nickname, avatarUrl: p.avatarUrl);
    } catch (e) {
      return Left(UnknownFailure('Update profile failed: ${e.toString()}'));
    }
  }
}
