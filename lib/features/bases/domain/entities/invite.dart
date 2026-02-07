import 'package:moonbase_skeleton/core/ids.dart';

class Invite {
  const Invite({
    required this.id,
    required this.baseId,
    required this.code,
    required this.createdByUserId,
    required this.createdAt,
    this.expiresAt,
    this.maxUses,
    this.usedCount = 0,
  });

  final InviteId id;
  final BaseId baseId;
  final String code; // human-shareable short code
  final UserId createdByUserId;
  final DateTime createdAt;
  final DateTime? expiresAt; // null => no expiry
  final int? maxUses; // null => unlimited
  final int usedCount;

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get isDepleted => maxUses != null && usedCount >= maxUses!;
  bool get isValid => !isExpired && !isDepleted;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Invite &&
        other.id == id &&
        other.baseId == baseId &&
        other.code == code &&
        other.createdByUserId == createdByUserId &&
        other.createdAt == createdAt &&
        other.expiresAt == expiresAt &&
        other.maxUses == maxUses &&
        other.usedCount == usedCount;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      baseId,
      code,
      createdByUserId,
      createdAt,
      expiresAt,
      maxUses,
      usedCount,
    );
  }

  @override
  String toString() {
    return 'Invite(id: $id, baseId: $baseId, code: $code, createdByUserId: $createdByUserId, createdAt: $createdAt, expiresAt: $expiresAt, maxUses: $maxUses, usedCount: $usedCount)';
  }
}
