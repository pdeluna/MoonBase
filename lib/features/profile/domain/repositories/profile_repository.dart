import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/features/profile/domain/entities/profile.dart';

abstract class ProfileRepository {
  Future<Either<Failure, Profile?>> getProfile(String userId);
  Future<Either<Failure, Profile>> updateProfile({
    required String userId,
    String? nickname,
    String? avatarUrl,
  });
}
