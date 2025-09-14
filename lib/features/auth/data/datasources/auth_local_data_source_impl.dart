import 'package:shared_preferences/shared_preferences.dart';
import 'package:moonbase_skeleton/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:moonbase_skeleton/features/auth/data/models/user_model.dart';
import 'dart:convert';

/// AuthLocalDataSource implementation that delegates to profile/session storage
/// to maintain consistency with the ProfileRepository's data structure.
/// 
/// This ensures that auth operations use the same storage keys and format
/// as the profile system, preventing data inconsistencies.
class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  AuthLocalDataSourceImpl(this.prefs);
  final SharedPreferences prefs;

  // Use the same keys as ProfileRepositoryImpl for consistency
  static const _kCurrent = 'currentUserId';
  static const _kProfiles = 'profiles';
  static const _kHandles = 'handlesIndex';

  /// Get profiles map with proper error handling
  Map<String, dynamic> _profiles() {
    final raw = prefs.getString(_kProfiles);
    if (raw == null) return <String, dynamic>{};
    
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return <String, dynamic>{};
    } catch (e) {
      return <String, dynamic>{};
    }
  }

  /// Get handles index with proper error handling
  Map<String, dynamic> _handles() {
    final raw = prefs.getString(_kHandles);
    if (raw == null) return <String, dynamic>{};
    
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return <String, dynamic>{};
    } catch (e) {
      return <String, dynamic>{};
    }
  }

  /// Save profiles map with fresh copy to prevent nested encoding
  Future<void> _saveProfiles(Map<String, dynamic> map) async {
    final freshMap = Map<String, dynamic>.from(map);
    await prefs.setString(_kProfiles, jsonEncode(freshMap));
  }

  /// Save handles index with fresh copy to prevent nested encoding
  Future<void> _saveHandles(Map<String, dynamic> map) async {
    final freshMap = Map<String, dynamic>.from(map);
    await prefs.setString(_kHandles, jsonEncode(freshMap));
  }

  @override
  Future<UserModel?> readCurrentUser() async {
    final id = prefs.getString(_kCurrent);
    if (id == null) return null;
    
    final profiles = _profiles();
    final profileJson = profiles[id] as Map<String, dynamic>?;
    if (profileJson == null) return null;
    
    // Defensive parsing to avoid cast crashes from malformed data
    // Handles cases where fields are missing, null, or wrong type
    final nickname = (profileJson['nickname'] as String?) ?? '';
    return UserModel(
      id: (profileJson['userId'] as String?) ?? id,
      nickname: nickname,
    );
  }

  @override
  Future<void> writeCurrentUser(UserModel user) async {
    // If a profile already exists, just point current; else create a bare one.
    final profiles = _profiles();
    
    // Check if profile already exists
    if (!profiles.containsKey(user.id)) {
      // Create a minimal profile entry
      profiles[user.id] = {
        'userId': user.id,
        'nickname': user.nickname,
        'avatarUrl': null,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      };
      await _saveProfiles(profiles);
    }
    
    // Set as current user
    await prefs.setString(_kCurrent, user.id);

    // Update handle index for fast nickname lookup
    final key = user.nickname.trim().toLowerCase();
    if (key.isNotEmpty) {
      final handles = _handles();
      handles[key] = user.id;
      await _saveHandles(handles);
    }
  }

  @override
  Future<void> clear() async {
    // Only clear current user pointer, don't delete profiles
    // This maintains consistency with ProfileRepository.clear()
    await prefs.remove(_kCurrent);
  }
}
