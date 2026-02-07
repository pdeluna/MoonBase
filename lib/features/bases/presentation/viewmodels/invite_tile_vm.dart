import 'package:moonbase_skeleton/features/bases/domain/entities/invite.dart';

class InviteTileVM {
  const InviteTileVM({
    required this.id,
    required this.code,
    required this.createdAt,
    required this.expiresAt,
    required this.maxUses,
    required this.usedCount,
    required this.isExpired,
    required this.isDepleted,
    required this.isValid,
  });

  factory InviteTileVM.fromInvite(Invite invite) {
    return InviteTileVM(
      id: invite.id.value,
      code: invite.code,
      createdAt: invite.createdAt,
      expiresAt: invite.expiresAt,
      maxUses: invite.maxUses,
      usedCount: invite.usedCount,
      isExpired: invite.isExpired,
      isDepleted: invite.isDepleted,
      isValid: invite.isValid,
    );
  }

  final String id;
  final String code;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final int? maxUses;
  final int usedCount;
  final bool isExpired;
  final bool isDepleted;
  final bool isValid;
}
