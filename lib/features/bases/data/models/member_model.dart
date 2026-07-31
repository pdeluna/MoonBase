import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base_member.dart';

class MemberModel {
  const MemberModel({
    required this.userId,
    required this.role,
    required this.nickname,
    required this.joinedAt,
  });

  /// Firestore `bases/{baseId}/members/{uid}` → model. Doc id is [userId].
  factory MemberModel.fromFirestore(String userId, Map<String, dynamic> data) {
    final rawJoined = data['joinedAt'];
    final joinedAt = switch (rawJoined) {
      Timestamp ts => ts.toDate().toUtc(),
      DateTime dt => dt.toUtc(),
      _ => DateTime.now().toUtc(),
    };
    return MemberModel(
      userId: userId,
      role: data['role'] as String? ?? 'member',
      nickname: data['nickname'] as String? ?? '',
      joinedAt: joinedAt,
    );
  }

  final String userId;
  final String role;
  final String nickname;
  final DateTime joinedAt;

  BaseMember toEntity() => BaseMember(
        userId: userId.uid,
        role: role,
        nickname: nickname,
        joinedAt: joinedAt,
      );

  /// Exactly the keys allowed by `firestore.rules` members create `hasOnly`.
  Map<String, dynamic> toFirestore() => {
        'role': role,
        'nickname': nickname,
        'joinedAt': Timestamp.fromDate(joinedAt.toUtc()),
        'schemaVersion': 1,
      };
}
