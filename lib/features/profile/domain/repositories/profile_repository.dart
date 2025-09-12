import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/profile/domain/entities/profile.dart';

abstract class ProfileRepository {
  Future<Either<Failure, Profile?>> getProfile(UserId userId);
  Future<Either<Failure, Profile>> updateProfile({
    required UserId userId,
    String? nickname,
    String? avatarUrl,
  });
}
