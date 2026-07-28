import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:moonbase_skeleton/features/profile/data/datasources/profile_local_data_source.dart';
import 'package:moonbase_skeleton/features/profile/data/models/profile_model.dart';

/// SharedPreferences-backed [ProfileLocalDataSource] (tests + legacy session paths).
class ProfileSharedPrefsDataSource implements ProfileLocalDataSource {
  ProfileSharedPrefsDataSource(this.prefs);

  final SharedPreferences prefs;

  static const kProfiles = 'profiles';

  Map<String, dynamic> _profilesJson() {
    final raw = prefs.getString(kProfiles);
    if (raw == null) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _saveProfiles(Map<String, dynamic> map) async {
    await prefs.setString(kProfiles, jsonEncode(Map<String, dynamic>.from(map)));
  }

  @override
  Future<ProfileModel?> readProfile(String userId) async {
    final profileJson = _profilesJson()[userId] as Map<String, dynamic>?;
    if (profileJson == null) return null;
    return ProfileModel.fromMap(profileJson);
  }

  @override
  Future<ProfileModel> writeProfile(ProfileModel profile) async {
    final profiles = _profilesJson();
    profiles[profile.userId] = profile.toMap();
    await _saveProfiles(profiles);
    return profile;
  }

  Future<void> deleteProfile(String userId) async {
    final profiles = _profilesJson();
    profiles.remove(userId);
    await _saveProfiles(profiles);
  }
}
