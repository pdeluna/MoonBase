import 'package:moonbase_skeleton/features/auth/data/models/user_model.dart';

/// Placeholder for future backend (e.g., Firebase). Keep it even if unused now.
abstract class AuthRemoteDataSource {
  Future<UserModel> signInWithNickname(String nickname);
  Future<void> signOut();
}