import '../models/base_model.dart';

/// Placeholder for future backend; keep interface even if unused for now.
abstract class BaseRemoteDataSource {
  Future<BaseModel> createBase({required String name, required String ownerUserId});
  Future<BaseModel> joinBase({required String inviteCode, required String userId});
  Future<List<BaseModel>> listBasesForUser(String userId);
  Future<void> renameBase({required String baseId, required String newName, required String requesterUserId});
  Future<void> deleteBase({required String baseId, required String requesterUserId});
  Future<String> generateInviteCode({required String baseId, required String requesterUserId});
}
