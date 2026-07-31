import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/error_mapper.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/profile/data/datasources/profile_firestore_data_source.dart';
import 'package:moonbase_skeleton/features/profile/data/datasources/profile_local_data_source.dart';
import 'package:moonbase_skeleton/features/profile/data/datasources/profile_shared_prefs_data_source.dart';
import 'package:moonbase_skeleton/features/profile/data/models/profile_model.dart';
import 'package:moonbase_skeleton/features/profile/domain/entities/profile.dart';
import 'package:moonbase_skeleton/features/profile/domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({
    required this.local,
    required this.prefs,
    fb.FirebaseAuth? auth,
  }) : _authOverride = auth;

  /// Convenience for unit tests that still use SharedPreferences only.
  factory ProfileRepositoryImpl.sharedPrefs(SharedPreferences prefs) {
    return ProfileRepositoryImpl(
      local: ProfileSharedPrefsDataSource(prefs),
      prefs: prefs,
    );
  }

  final ProfileLocalDataSource local;
  final SharedPreferences prefs;
  final fb.FirebaseAuth? _authOverride;

  static const _kCurrent = 'currentUserId';
  static const _kHandles = 'handlesIndex';

  Future<void> _writeMutex = Future<void>.value();

  /// Prefer Auth UID when Firebase is initialized; else prefs `currentUserId`.
  String? _sessionUid() {
    final override = _authOverride;
    if (override != null) return override.currentUser?.uid;
    if (Firebase.apps.isEmpty) return null;
    return fb.FirebaseAuth.instance.currentUser?.uid;
  }
  Map<String, dynamic> _handlesIndex() {
    final raw = prefs.getString(_kHandles);
    if (raw == null) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _saveHandlesIndex(Map<String, dynamic> map) async {
    await prefs.setString(_kHandles, jsonEncode(Map<String, dynamic>.from(map)));
  }

  String _normalizeHandle(String handle) => handle.trim().toLowerCase();

  String? _getMostRecentUserForHandle(String normalizedHandle) {
    return _handlesIndex()[normalizedHandle] as String?;
  }

  Future<void> _updateHandleMapping(String normalizedHandle, String userId) async {
    final handles = _handlesIndex();
    handles[normalizedHandle] = userId;
    await _saveHandlesIndex(handles);
  }

  Future<T> _withWriteLock<T>(Future<T> Function() critical) {
    final previous = _writeMutex;
    final completer = Completer<void>();
    _writeMutex = completer.future;
    return previous.then((_) => critical()).whenComplete(completer.complete);
  }

  @override
  Future<Either<Failure, Profile?>> getProfile(UserId userId) =>
      guard(() async {
        final model = await local.readProfile(userId.value);
        return model?.toEntity();
      });

  @override
  Future<Either<Failure, Profile>> updateProfile({
    required UserId userId,
    String? nickname,
    String? avatarUrl,
  }) =>
      guard(() => _withWriteLock(() async {
        final existing = await local.readProfile(userId.value);
        if (existing == null) {
          throw const CacheFailure('Profile not found');
        }

        final nowUtc = DateTime.now().toUtc();
        final trimmedNick = nickname?.trim();
        final trimmedAvatar = avatarUrl?.trim();

        final updated = ProfileModel(
          userId: userId.value,
          nickname: trimmedNick ?? existing.nickname,
          avatarUrl: trimmedAvatar ?? existing.avatarUrl,
          themeMode: existing.themeMode,
          createdAt: existing.createdAt,
          updatedAt: nowUtc,
        );

        final written = await local.writeProfile(updated);
        return written.toEntity();
      }));

  @override
  Future<Either<Failure, Profile?>> readCurrent() =>
      guard(() async {
        final id = _sessionUid() ?? prefs.getString(_kCurrent);
        if (id == null) return null;
        final model = await local.readProfile(id);
        return model?.toEntity();
      });

  @override
  Future<Either<Failure, Profile>> signInByHandleOrCreate(String handle) =>
      guard(() => _withWriteLock(() async {
        // Legacy prefs/handle session path (unit tests). Production Auth uses
        // Firebase + [ProfileFirestoreDataSource.readProfile] create-or-return.
        final normalizedHandle = _normalizeHandle(handle);
        String? userId = _getMostRecentUserForHandle(normalizedHandle);

        if (userId != null) {
          final existing = await local.readProfile(userId);
          if (existing == null) userId = null;
        }

        if (userId == null) {
          userId = const Uuid().v4();
          final nowUtc = DateTime.now().toUtc();
          await local.writeProfile(
            ProfileModel(
              userId: userId,
              nickname: handle.trim(),
              avatarUrl: null,
              themeMode: 'light',
              createdAt: nowUtc,
              updatedAt: nowUtc,
            ),
          );
        }

        await _updateHandleMapping(normalizedHandle, userId);
        await prefs.setString(_kCurrent, userId);

        final model = await local.readProfile(userId);
        if (model == null) {
          throw const CacheFailure('Profile missing after sign-in');
        }
        return model.toEntity();
      }));

  @override
  Future<Either<Failure, Unit>> deleteProfile(UserId userId) =>
      guard(() => _withWriteLock(() async {
        final existing = await local.readProfile(userId.value);
        if (existing == null) return Unit.instance;

        final normalizedHandle = _normalizeHandle(existing.nickname);

        final ds = local;
        if (ds is ProfileFirestoreDataSource) {
          await ds.deleteProfile(userId.value);
        } else if (ds is ProfileSharedPrefsDataSource) {
          await ds.deleteProfile(userId.value);
        }

        final currentUserIdForHandle = _getMostRecentUserForHandle(normalizedHandle);
        if (currentUserIdForHandle == userId.value) {
          final handles = _handlesIndex();
          handles.remove(normalizedHandle);
          await _saveHandlesIndex(handles);
        }

        final currentUserId = prefs.getString(_kCurrent);
        if (currentUserId == userId.value) {
          await prefs.remove(_kCurrent);
        }

        return Unit.instance;
      }));

  @override
  Future<Either<Failure, Unit>> clear() =>
      guard(() => _withWriteLock(() async {
        await prefs.remove(_kCurrent);
        return Unit.instance;
      }));
}
