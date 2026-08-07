import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

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

  Never _mapFirebaseException(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'network-request-failed':
      case 'too-many-requests':
        throw NetworkFailure(e.message ?? 'Network error');
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-credential':
      case 'invalid-email':
      case 'user-disabled':
        throw ValidationFailure(e.message ?? 'Invalid email or password.');
      case 'email-already-in-use':
        throw ValidationFailure(e.message ?? 'That email is already in use.');
      case 'weak-password':
        throw ValidationFailure(e.message ?? 'Password is too weak.');
      default:
        throw UnknownFailure(e.message ?? e.code);
    }
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
        throw const UnknownFailure('Sign-up succeeded but no user was returned.');
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
    // TEMP DIAG_HANG — remove after incident root-cause confirmed
    final sw = Stopwatch()..start();
    debugPrint(
      'DIAG_HANG signInWithEmailAndPassword BEFORE email=$email '
      't=${DateTime.now().toIso8601String()}',
    );
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = cred.user;
      if (user == null) {
        debugPrint(
          'DIAG_HANG signInWithEmailAndPassword AFTER null-user '
          'elapsedMs=${sw.elapsedMilliseconds}',
        );
        throw const UnknownFailure('Sign-in succeeded but no user was returned.');
      }
      debugPrint(
        'DIAG_HANG signInWithEmailAndPassword AFTER success '
        'uid=${user.uid} elapsedMs=${sw.elapsedMilliseconds}',
      );
      return _toModel(user);
    } on fb.FirebaseAuthException catch (e) {
      debugPrint(
        'DIAG_HANG signInWithEmailAndPassword AFTER throw '
        'code=${e.code} elapsedMs=${sw.elapsedMilliseconds}',
      );
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
