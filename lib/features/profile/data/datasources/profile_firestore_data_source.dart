import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'package:moonbase_skeleton/features/auth/data/datasources/firebase_auth_remote_data_source.dart';
import 'package:moonbase_skeleton/features/profile/data/datasources/profile_local_data_source.dart';
import 'package:moonbase_skeleton/features/profile/data/models/profile_model.dart';

/// Cloud Firestore `users/{uid}` — conforms to docs/FIRESTORE_SCHEMA.md + firestore.rules.
///
/// Create-or-return for missing docs lives here (not in Auth). Auth only calls
/// [readProfile] after a successful sign-in / session restore.
class ProfileFirestoreDataSource implements ProfileLocalDataSource {
  ProfileFirestoreDataSource({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final fb.FirebaseAuth _auth;

  static const _schemaVersion = 1;
  static const _defaultThemeMode = 'light';

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection('users').doc(uid);

  @override
  Future<ProfileModel?> readProfile(String userId) async {
    final ref = _userRef(userId);
    final existing = await ref.get();
    if (existing.exists && existing.data() != null) {
      return ProfileModel.fromFirestore(userId, existing.data()!);
    }

    final authUser = _auth.currentUser;
    if (authUser == null || authUser.uid != userId) {
      return null;
    }

    final nickname = _nicknameFromAuth(authUser);

    // Create-only-if-absent: concurrent readers share one write via transaction.
    await _db.runTransaction((txn) async {
      final snap = await txn.get(ref);
      if (snap.exists) return;
      txn.set(ref, <String, dynamic>{
        'nickname': nickname,
        'themeMode': _defaultThemeMode,
        'createdAt': FieldValue.serverTimestamp(),
        'schemaVersion': _schemaVersion,
      });
    });

    final after = await ref.get();
    if (!after.exists || after.data() == null) return null;
    return ProfileModel.fromFirestore(userId, after.data()!);
  }

  @override
  Future<ProfileModel> writeProfile(ProfileModel profile) async {
    await _userRef(profile.userId).set(profile.toFirestore());
    final snap = await _userRef(profile.userId).get();
    final data = snap.data();
    if (data == null) return profile;
    return ProfileModel.fromFirestore(profile.userId, data);
  }

  Future<void> deleteProfile(String userId) async {
    await _userRef(userId).delete();
  }

  String _nicknameFromAuth(fb.User user) {
    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return _clampNickname(displayName);
    }
    final email = user.email ?? '';
    return _clampNickname(
      FirebaseAuthRemoteDataSource.nicknameFromEmail(
        email.isEmpty ? user.uid : email,
      ),
    );
  }

  /// Rules require nickname length 2–24.
  String _clampNickname(String raw) {
    final trimmed = raw.trim();
    if (trimmed.length >= 2 && trimmed.length <= 24) return trimmed;
    if (trimmed.length > 24) return trimmed.substring(0, 24);
    if (trimmed.isEmpty) return 'user';
    return '${trimmed}_';
  }
}
