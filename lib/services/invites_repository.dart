import 'package:moonbase_skeleton/models/base_member.dart';
import 'package:moonbase_skeleton/models/invite.dart';

abstract class InvitesRepository {
  /// Create an invite for a base. Only the owner can create invites.
  /// Throws an exception if the user is not the owner of the base.
  Future<BaseInvite> createInvite({
    required String baseId, 
    required String userId, // The user creating the invite (must be owner)
    int? maxUses, 
    DateTime? expiresAt
  });
  
  /// Redeem an invite code. Validates expiration and usage limits,
  /// increments usedCount, and adds the user as a member with 'member' role.
  /// Throws an exception if the invite is invalid, expired, or depleted.
  Future<BaseMember> redeemInvite({required String code, required String userId});
  
  /// Get an invite by its code
  Future<BaseInvite?> getByCode(String code);
}