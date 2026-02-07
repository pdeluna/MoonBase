import 'package:moonbase_skeleton/features/bases/data/models/base_model.dart';
import 'package:moonbase_skeleton/features/bases/data/models/invite_model.dart';

abstract class BaseLocalDataSource {
  Future<List<BaseModel>> listBasesForUser(String userId);
  Future<BaseModel> createBase({required String name, required String ownerUserId});
  Future<BaseModel> joinBase({required String inviteCode, required String userId});
  Future<void> leaveBase({required String baseId, required String userId});
  Future<void> renameBase({required String baseId, required String newName});
  Future<void> deleteBase({required String baseId});
  Future<String> generateInviteCode({required String baseId});
  
  // Invite methods
  Future<InviteModel> createInvite({
    required String baseId,
    required String createdByUserId,
    int? maxUses,
    DateTime? expiresAt,
  });
  Future<List<InviteModel>> listInvitesForBase(String baseId);
  Future<InviteModel?> getInviteByCode(String code);
  
  // Last accessed base methods (per user)
  Future<BaseModel?> getLastAccessedBase(String userId);
  Future<void> setLastAccessedBase(String userId, String baseId);
}
