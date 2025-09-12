import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/features/profile/domain/entities/profile.dart';
import 'package:moonbase_skeleton/features/profile/domain/repositories/profile_repository.dart';
import 'package:moonbase_skeleton/core/validators.dart';

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
Future<Either<Failure, Profile>> call(UpdateProfileParams p) {
  if (p.nickname != null) {
    final nick = p.nickname!.trim();
    if (!isValidNickname(nick)) {
      return Future.value(const Left(ValidationFailure('Nickname must be 1–24 chars (letters, numbers, space, _ . -).')));
    }
    // pass trimmed nick onward
    return repo.updateProfile(userId: p.userId, nickname: nick, avatarUrl: p.avatarUrl);
  }
  return repo.updateProfile(userId: p.userId, avatarUrl: p.avatarUrl);
}
}
