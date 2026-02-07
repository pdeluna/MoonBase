import 'package:moonbase_skeleton/features/bases/domain/entities/invite.dart';
import 'package:moonbase_skeleton/core/ids.dart';

class InviteModel {
  const InviteModel({
    required this.id,
    required this.baseId,
    required this.code,
    required this.createdByUserId,
    required this.createdAt,
    this.expiresAt,
    this.maxUses,
    this.usedCount = 0,
  });

  factory InviteModel.fromMap(Map<String, dynamic> map) => InviteModel(
    id: map['id'] as String,
    baseId: map['baseId'] as String,
    code: map['code'] as String,
    createdByUserId: map['createdByUserId'] as String,
    createdAt: DateTime.parse(map['createdAt'] as String),
    expiresAt: map['expiresAt'] != null ? DateTime.parse(map['expiresAt'] as String) : null,
    maxUses: map['maxUses'] as int?,
    usedCount: (map['usedCount'] ?? 0) as int,
  );

  final String id;
  final String baseId;
  final String code;
  final String createdByUserId;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final int? maxUses;
  final int usedCount;

  Invite toEntity() => Invite(
    id: id.iid,
    baseId: baseId.bid,
    code: code,
    createdByUserId: createdByUserId.uid,
    createdAt: createdAt,
    expiresAt: expiresAt,
    maxUses: maxUses,
    usedCount: usedCount,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'baseId': baseId,
    'code': code,
    'createdByUserId': createdByUserId,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt?.toIso8601String(),
    'maxUses': maxUses,
    'usedCount': usedCount,
  };
}
