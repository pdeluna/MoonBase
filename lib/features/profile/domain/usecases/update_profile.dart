import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/features/profile/domain/entities/profile.dart';
import 'package:moonbase_skeleton/features/profile/domain/repositories/profile_repository.dart';

class UpdateProfileParams {
  const UpdateProfileParams({
    required this.userId,
    this.nickname,
    this.avatarUrl,
  });

  final UserId userId;
  final String? nickname;
  final String? avatarUrl;
}

class UpdateProfile implements UseCase<Profile, UpdateProfileParams> {
  const UpdateProfile(this.repo);

  final ProfileRepository repo;

  @override
  Future<Either<Failure, Profile>> call(UpdateProfileParams p) =>
      repo.updateProfile(userId: p.userId, nickname: p.nickname, avatarUrl: p.avatarUrl);
}
