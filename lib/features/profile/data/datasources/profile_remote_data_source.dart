import '../models/profile_model.dart';

/// Placeholder for future backend sync.
abstract class ProfileRemoteDataSource {
  Future<ProfileModel?> fetchProfile(String userId);
  Future<ProfileModel> updateProfile(ProfileModel profile);
}
