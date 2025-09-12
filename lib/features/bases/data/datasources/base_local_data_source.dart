import '../models/base_model.dart';

abstract class BaseLocalDataSource {
  Future<List<BaseModel>> listBasesForUser(String userId);
  Future<BaseModel> createBase({required String name, required String ownerUserId});
  Future<BaseModel> joinBase({required String inviteCode, required String userId});
  Future<void> leaveBase({required String baseId, required String userId});
  Future<void> renameBase({required String baseId, required String newName});
  Future<void> deleteBase({required String baseId});
  Future<String> generateInviteCode({required String baseId});
}
