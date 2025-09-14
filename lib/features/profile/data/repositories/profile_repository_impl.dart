import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/profile/domain/entities/profile.dart';
import 'package:moonbase_skeleton/features/profile/domain/repositories/profile_repository.dart';
import 'package:moonbase_skeleton/core/error_mapper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:async';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this.prefs);

  final SharedPreferences prefs;
  static const _kProfiles = 'profiles';
  static const _kCurrent = 'currentUserId';
  static const _kHandles = 'handlesIndex';

  /// Mutex to ensure atomic read-modify-write operations
  /// Prevents race conditions when multiple operations try to modify data simultaneously
  Completer<void> _writeMutex = Completer<void>()..complete();

  /// Handle normalization and uniqueness rules:
  /// 
  /// 1. HANDLE NORMALIZATION: All handles are normalized using trim().toLowerCase()
  ///    - "Alice" and "alice" and " ALICE " all become "alice"
  ///    - This enables case-insensitive login
  /// 
  /// 2. HANDLE UNIQUENESS: Handles are NOT unique across users
  ///    - Multiple users can have the same handle (e.g., "alice")
  ///    - This is common in closed-circle apps where handles are more like display names
  ///    - User uniqueness is enforced by UUID only
  /// 
  /// 3. HANDLES INDEX: Maps normalized handle -> most recent user with that handle
  ///    - If multiple users have "alice", the index points to the last one who signed in
  ///    - This provides a "default" user for that handle while allowing duplicates
  /// 
  /// 4. LOGIN BEHAVIOR: signInByHandleOrCreate() will:
  ///    - Find existing user with that handle (if any) and sign them in
  ///    - If no user exists with that handle, create a new user
  ///    - Update the handles index to point to the signed-in user


  Map<String, dynamic> _profilesJson() {
    final raw = prefs.getString(_kProfiles);
    if (raw == null) return <String, dynamic>{};
    
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      // If decoded is not a Map, return empty map
      return <String, dynamic>{};
    } catch (e) {
      // If JSON is malformed, return empty map
      return <String, dynamic>{};
    }
  }

  Future<void> _saveProfiles(Map<String, dynamic> map) async {
    // Ensure we're encoding a fresh Map, not already-encoded data
    final freshMap = Map<String, dynamic>.from(map);
    await prefs.setString(_kProfiles, jsonEncode(freshMap));
  }

  String? _currentUserId() => prefs.getString(_kCurrent);

  Map<String, dynamic> _handlesIndex() {
    final raw = prefs.getString(_kHandles);
    if (raw == null) return <String, dynamic>{};
    
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      // If decoded is not a Map, return empty map
      return <String, dynamic>{};
    } catch (e) {
      // If JSON is malformed, return empty map
      return <String, dynamic>{};
    }
  }

  Future<void> _saveHandlesIndex(Map<String, dynamic> map) async {
    // Ensure we're encoding a fresh Map, not already-encoded data
    final freshMap = Map<String, dynamic>.from(map);
    await prefs.setString(_kHandles, jsonEncode(freshMap));
  }

  /// Normalizes a handle for consistent storage and lookup
  String _normalizeHandle(String handle) => handle.trim().toLowerCase();

  /// Gets the most recent user ID associated with a normalized handle
  String? _getMostRecentUserForHandle(String normalizedHandle) {
    final handles = _handlesIndex();
    return handles[normalizedHandle] as String?;
  }

  /// Updates the handles index to point to the given user for the given handle
  Future<void> _updateHandleMapping(String normalizedHandle, String userId) async {
    final handles = _handlesIndex();
    handles[normalizedHandle] = userId;
    await _saveHandlesIndex(handles);
  }

  /// Acquires the write mutex to ensure atomic operations
  /// Returns a function to release the mutex when done
  Future<void Function()> _acquireWriteLock() async {
    await _writeMutex.future;
    final newMutex = Completer<void>();
    _writeMutex = newMutex;
    return () => newMutex.complete();
  }

  @override
  Future<Either<Failure, Profile?>> getProfile(UserId userId) =>
    guard(() async {
      final profiles = _profilesJson();
      final profileJson = profiles[userId.value] as Map<String, dynamic>?;
      return profileJson == null ? null : Profile.fromJson(profileJson);
    });

  @override
  Future<Either<Failure, Profile>> updateProfile({
    required UserId userId,
    String? nickname,
    String? avatarUrl,
  }) =>
    guard(() async {
      final releaseLock = await _acquireWriteLock();
      try {
        final profiles = _profilesJson();
        final existingJson = profiles[userId.value] as Map<String, dynamic>?;
        
        final nowUtc = DateTime.now().toUtc();
        final trimmedNick = nickname?.trim();
        final trimmedAvatar = avatarUrl?.trim();

        final updatedProfile = Profile(
          userId: userId,
          nickname: trimmedNick ?? (existingJson?['nickname'] as String?) ?? '',
          avatarUrl: trimmedAvatar ?? (existingJson?['avatarUrl'] as String?),
          updatedAt: nowUtc,
        );

        profiles[userId.value] = updatedProfile.toJson();
        await _saveProfiles(profiles);
        return updatedProfile;
      } finally {
        releaseLock();
      }
    });

  @override
  Future<Either<Failure, Profile?>> readCurrent() =>
    guard(() async {
      final id = _currentUserId();
      if (id == null) return null;
      final map = _profilesJson();
      final p = map[id] as Map<String, dynamic>?;
      return p == null ? null : Profile.fromJson(p);
    });

  @override
  Future<Either<Failure, Profile>> signInByHandleOrCreate(String handle) =>
    guard(() async {
      final releaseLock = await _acquireWriteLock();
      try {
        final normalizedHandle = _normalizeHandle(handle);
        final profiles = _profilesJson();

        // Try to find existing user with this handle
        String? userId = _getMostRecentUserForHandle(normalizedHandle);
        
        // Check if the user still exists in profiles
        if (userId != null && profiles[userId] == null) {
          // User was deleted but handle mapping still exists, clear it
          userId = null;
        }

        if (userId == null) {
          // No existing user with this handle, create a new one
          userId = const Uuid().v4();
          final nowUtc = DateTime.now().toUtc();
          final profile = Profile(
            userId: UserId(userId),
            nickname: handle.trim(), // Store original handle (not normalized)
            avatarUrl: null,
            updatedAt: nowUtc,
          );
          
          // Save the new profile
          profiles[userId] = profile.toJson();
          await _saveProfiles(profiles);
        }

        // Update handle mapping to point to this user (most recent user with this handle)
        await _updateHandleMapping(normalizedHandle, userId);

        // Set as current user
        await prefs.setString(_kCurrent, userId);
        
        // Return the profile
        final json = profiles[userId] as Map<String, dynamic>;
        return Profile.fromJson(json);
      } finally {
        releaseLock();
      }
    });

  @override
  Future<Either<Failure, Unit>> deleteProfile(UserId userId) =>
    guard(() async {
      final releaseLock = await _acquireWriteLock();
      try {
        final profiles = _profilesJson();
        final profileJson = profiles[userId.value] as Map<String, dynamic>?;
        
        if (profileJson == null) {
          // Profile doesn't exist, nothing to delete
          return Unit.instance;
        }
        
        // Get the profile to find its handle for cleanup
        final profile = Profile.fromJson(profileJson);
        final normalizedHandle = _normalizeHandle(profile.nickname);
        
        // Remove from profiles
        profiles.remove(userId.value);
        await _saveProfiles(profiles);
        
        // Clean up handle mapping if this was the most recent user with this handle
        final currentUserIdForHandle = _getMostRecentUserForHandle(normalizedHandle);
        if (currentUserIdForHandle == userId.value) {
          // This was the most recent user with this handle, remove the mapping
          final handles = _handlesIndex();
          handles.remove(normalizedHandle);
          await _saveHandlesIndex(handles);
        }
        
        // If this was the current user, clear the current user
        final currentUserId = _currentUserId();
        if (currentUserId == userId.value) {
          await prefs.remove(_kCurrent);
        }
        
        return Unit.instance;
      } finally {
        releaseLock();
      }
    });

  @override
  Future<Either<Failure, Unit>> clear() =>
    guard(() async {
      final releaseLock = await _acquireWriteLock();
      try {
        await prefs.remove(_kCurrent);
        return Unit.instance;
      } finally {
        releaseLock();
      }
    });
}
