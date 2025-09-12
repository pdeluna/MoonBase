import 'package:moonbase_skeleton/features/profile/data/models/profile_model.dart';

abstract class ProfileLocalDataSource {
  Future<ProfileModel?> readProfile(String userId);
  Future<ProfileModel> writeProfile(ProfileModel profile);
}
