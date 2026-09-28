import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'package:moonbase_skeleton/core/error_mapper.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:moonbase_skeleton/features/auth/data/models/user_model.dart';

/// Firebase Auth implementation of [AuthRemoteDataSource] for owner email/password.
class FirebaseAuthRemoteDataSource implements AuthRemoteDataSource {
  FirebaseAuthRemoteDataSource({fb.FirebaseAuth? auth})
      : _auth = auth ?? fb.FirebaseAuth.instance;

  final fb.FirebaseAuth _auth;

  static String nicknameFromEmail(String email) {
    final at = email.indexOf('@');
    final localPart = at > 0 ? email.substring(0, at) : email;
    return localPart.isEmpty ? email : localPart;
  }

  UserModel _toModel(fb.User user) {
    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return UserModel(id: user.uid, nickname: displayName);
    }
    final email = user.email ?? '';
    return UserModel(
      id: user.uid,
      nickname: nicknameFromEmail(email.isEmpty ? user.uid : email),
    );
  }

  /// Maps a Firebase Auth error to a [Failure]. The Firebase sentence stays
  /// on [Failure.debugDetail]; [userMessage] reads the plain [Failure.message].
  static Failure mapAuthException(fb.FirebaseAuthException e) {
    return mapAuthFirebaseCode(e.code, e.message) ??
        UnknownFailure(kGenericFailureCopy, e.message ?? e.code);
  }

  Never _mapFirebaseException(fb.FirebaseAuthException e) {
    throw mapAuthException(e);
  }

  @override
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String nickname,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = cred.user;
      if (user == null) {
        throw const UnknownFailure('Could not create your account. Try again.');
      }
      final trimmed = nickname.trim();
      await user.updateDisplayName(trimmed);
      await user.reload();
      final refreshed = _auth.currentUser ?? user;
      return UserModel(id: refreshed.uid, nickname: trimmed);
    } on fb.FirebaseAuthException catch (e) {
      _mapFirebaseException(e);
    }
  }

  @override
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = cred.user;
      if (user == null) {
        throw const UnknownFailure('Could not sign you in. Try again.');
      }
      return _toModel(user);
    } on fb.FirebaseAuthException catch (e) {
      _mapFirebaseException(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on fb.FirebaseAuthException catch (e) {
      _mapFirebaseException(e);
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _toModel(user);
  }
}
