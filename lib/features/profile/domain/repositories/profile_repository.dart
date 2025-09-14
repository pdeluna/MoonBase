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
  Future<Either<Failure, Unit>> deleteProfile(UserId userId);   // deletes profile by UUID

  // Session primitives
  Future<Either<Failure, Profile?>> readCurrent();              // returns current or null
  Future<Either<Failure, Profile>> signInByHandleOrCreate(String handle); // sets current
  Future<Either<Failure, Unit>> clear();                        // sets currentUserId = null

}
