import 'package:moonbase_skeleton/features/auth/data/models/user_model.dart';

/// Remote auth port (Firebase Auth for owners).
abstract class AuthRemoteDataSource {
  Future<UserModel> signUp({required String email, required String password});

  Future<UserModel> signIn({required String email, required String password});

  Future<void> signOut();

  /// Returns the persisted Firebase session user, or null if signed out.
  Future<UserModel?> getCurrentUser();
}
