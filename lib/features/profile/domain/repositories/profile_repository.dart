import '../../../../core/either.dart';
import '../../../../core/failure.dart';
import '../entities/profile.dart';

abstract class ProfileRepository {
  Future<Either<Failure, Profile?>> getProfile(String userId);
  Future<Either<Failure, Profile>> updateProfile({
    required String userId,
    String? nickname,
    String? avatarUrl,
  });
}
