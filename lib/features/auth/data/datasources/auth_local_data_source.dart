import 'package:moonbase_skeleton/features/auth/data/models/user_model.dart';

abstract class AuthLocalDataSource {
  Future<UserModel?> readCurrentUser();
  Future<void> writeCurrentUser(UserModel user);
  Future<void> clear();
}