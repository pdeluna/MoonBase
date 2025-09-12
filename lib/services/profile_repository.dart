import 'dart:convert';
import 'package:moonbase_skeleton/models/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Public abstraction (unchanged)
abstract class ProfileRepository {
  /// Returns the currently signed-in profile (based on the current-user pointer),
  /// or null if no one is signed in.
  Future<Profile?> read();

  /// Upsert the given profile and set it as the current user.
  Future<void> write(Profile profile);

  /// Sign out: clears only the "current user" pointer.
  /// Does NOT delete any saved profiles.
  Future<void> clear();

  /// Get a profile by user ID
  Future<Profile?> getProfileByUserId(String userId);
}

/// SharedPreferences-backed repository with an accounts index.
/// Structure:
/// - mb.users       : JSON object { nickname_case_sensitive : <Profile JSON> }
/// - mb.currentUser : string nickname_case_sensitive
/// (Legacy)
/// - mb.profile     : JSON string for a single profile (migrated on first read)
class SpProfileRepository implements ProfileRepository {
  static const _kUsers = 'mb.users';
  static const _kCurrent = 'mb.currentUser';
  // static const _kLegacySingle = 'mb.profile';

  // ---- helpers ----

  Future<Map<String, dynamic>> _readUsers(SharedPreferences sp) async {
    final raw = sp.getString(_kUsers);
    if (raw == null) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _writeUsers(SharedPreferences sp, Map<String, dynamic> users) async {
    await sp.setString(_kUsers, jsonEncode(users));
  }

  String? _currentKey(SharedPreferences sp) => sp.getString(_kCurrent);

  Future<void> _setCurrentKey(SharedPreferences sp, String key) async {
    await sp.setString(_kCurrent, key);
  }

  /// Migrate legacy single-profile storage into the users map.
  /// If legacy exists, it will:
  ///  - parse it into Profile,
  ///  - insert into mb.users under nickname_case_sensitive,
  ///  - set mb.currentUser,
  ///  - remove legacy key.
  // Future<void> _migrateLegacyIfNeeded(SharedPreferences sp) async {
  //   final legacy = sp.getString(_kLegacySingle);
  //   if (legacy == null) return;

  //   try {
  //     final map = jsonDecode(legacy) as Map<String, dynamic>;
  //     final profile = Profile.fromJson(map);
  //     final key = profile.nickname.trim(); // Use case-sensitive nickname

  //     final users = await _readUsers(sp);
  //     users[key] = profile.toJson();

  //     await _writeUsers(sp, users);
  //     await _setCurrentKey(sp, key);
  //   } catch (_) {
  //     // If legacy is corrupt, just drop it.
  //   } finally {
  //     await sp.remove(_kLegacySingle);
  //   }
  // }

  /// Normalize a dynamic entry coming from users map into a Map<String, dynamic>.
  Map<String, dynamic>? _asJsonMap(dynamic entry) {
    if (entry == null) return null;
    if (entry is Map<String, dynamic>) return entry;
    if (entry is String) {
      try {
        final d = jsonDecode(entry);
        return d is Map<String, dynamic> ? d : null;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  // ---- ProfileRepository implementation ----

  @override
  Future<Profile?> read() async {
    final sp = await SharedPreferences.getInstance();

    // One-time migration if needed
    // await _migrateLegacyIfNeeded(sp);

    final current = _currentKey(sp);
    if (current == null) return null;

    final users = await _readUsers(sp);
    final jsonMap = _asJsonMap(users[current]);
    if (jsonMap == null) return null;

    try {
      return Profile.fromJson(jsonMap);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(Profile profile) async {
    final sp = await SharedPreferences.getInstance();

    final key = profile.nickname.trim(); // Use case-sensitive nickname
    final users = await _readUsers(sp);

    users[key] = profile.toJson();
    await _writeUsers(sp, users);
    await _setCurrentKey(sp, key);
  }

  @override
  Future<void> clear() async {
    // Sign out: do NOT delete any user data. Just clear "current".
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kCurrent);
  }

  // ---- Convenience for Phase 1: sign-in by nickname on this device ----
  // Not part of the abstract interface on purpose (UI calls through SessionController).
  Future<Profile> signInByNickname(String nickname) async {
    final sp = await SharedPreferences.getInstance();

    // One-time migration if needed so old installs get picked up
    // await _migrateLegacyIfNeeded(sp);

    final key = nickname.trim(); // Use case-sensitive nickname
    final users = await _readUsers(sp);

    Profile profile;

    final existing = _asJsonMap(users[key]);
    if (existing != null) {
      profile = Profile.fromJson(existing);
    } else {
      // Create a new local-only profile with UUID
      profile = Profile(
        userId: const Uuid().v4(),
        nickname: nickname.trim(),
        createdAt: DateTime.now().toUtc().toIso8601String(),
        themeMode: 'light', // Default theme
      );
    }

    users[key] = profile.toJson();
    await _writeUsers(sp, users);
    await _setCurrentKey(sp, key);
    return profile;
  }

  /// Optional: permanently delete a stored account by nickname (not used in Phase 1).
  Future<void> deleteAccount(String nickname) async {
    final sp = await SharedPreferences.getInstance();
    final key = nickname.trim(); // Use case-sensitive nickname
    final users = await _readUsers(sp);
    users.remove(key);
    await _writeUsers(sp, users);

    if (_currentKey(sp) == key) {
      await sp.remove(_kCurrent);
    }
  }

  @override
  Future<Profile?> getProfileByUserId(String userId) async {
    final sp = await SharedPreferences.getInstance();
    final users = await _readUsers(sp);

    for (final entry in users.entries) {
      try {
        final profile = Profile.fromJson(entry.value as Map<String, dynamic>);
        if (profile.userId == userId) {
          return profile;
        }
      } catch (_) {
        // Skip corrupted profile entries
        continue;
      }
    }
    return null;
  }
}
