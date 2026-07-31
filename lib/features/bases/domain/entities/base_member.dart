import 'package:moonbase_skeleton/core/ids.dart';

/// Membership detail for a base (Firestore `members/{uid}` shape at the domain edge).
class BaseMember {
  const BaseMember({
    required this.userId,
    required this.role,
    required this.nickname,
    required this.joinedAt,
  });

  final UserId userId;
  final String role; // 'owner' | 'member'
  final String nickname;
  final DateTime joinedAt;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BaseMember &&
        other.userId == userId &&
        other.role == role &&
        other.nickname == nickname &&
        other.joinedAt == joinedAt;
  }

  @override
  int get hashCode => Object.hash(userId, role, nickname, joinedAt);
}
