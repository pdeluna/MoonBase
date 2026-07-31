import 'package:cloud_firestore/cloud_firestore.dart';
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
        expiresAt: map['expiresAt'] != null
            ? DateTime.parse(map['expiresAt'] as String)
            : null,
        maxUses: map['maxUses'] as int?,
        usedCount: (map['usedCount'] ?? 0) as int,
      );

  /// Firestore `bases/{baseId}/invites/{code}` → model. Doc id is [code].
  factory InviteModel.fromFirestore(
    String baseId,
    String code,
    Map<String, dynamic> data,
  ) {
    final rawCreated = data['createdAt'];
    final createdAt = switch (rawCreated) {
      Timestamp ts => ts.toDate().toUtc(),
      DateTime dt => dt.toUtc(),
      _ => DateTime.now().toUtc(),
    };
    final rawExpires = data['expiresAt'];
    final DateTime? expiresAt = switch (rawExpires) {
      Timestamp ts => ts.toDate().toUtc(),
      DateTime dt => dt.toUtc(),
      null => null,
      _ => null,
    };
    final rawMax = data['maxUses'];
    final int? maxUses = switch (rawMax) {
      int n => n,
      num n => n.toInt(),
      _ => null,
    };
    final rawUses = data['useCount'];
    final usedCount = switch (rawUses) {
      int n => n,
      num n => n.toInt(),
      _ => 0,
    };
    return InviteModel(
      id: code,
      baseId: baseId,
      code: code,
      createdByUserId: data['createdBy'] as String? ?? '',
      createdAt: createdAt,
      expiresAt: expiresAt,
      maxUses: maxUses,
      usedCount: usedCount,
    );
  }

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

  /// Exactly the keys allowed by `firestore.rules` invite create `hasOnly`.
  /// Omits null `maxUses` / `expiresAt` (rules allow absent or null).
  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'createdBy': createdByUserId,
      'createdAt': Timestamp.fromDate(createdAt.toUtc()),
      'useCount': usedCount,
      'schemaVersion': 1,
    };
    if (maxUses != null) map['maxUses'] = maxUses;
    if (expiresAt != null) {
      map['expiresAt'] = Timestamp.fromDate(expiresAt!.toUtc());
    }
    return map;
  }
}
