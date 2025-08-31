import 'dart:convert';

class BaseInvite {
  final String id; // uuid v4
  final String baseId;
  final String code; // human-shareable short code
  final String createdByUserId;
  final DateTime createdAt;
  final DateTime? expiresAt; // null => no expiry (dev only)
  final int? maxUses; // null => unlimited (dev only)
  final int usedCount;


  const BaseInvite({
    required this.id,
    required this.baseId,
    required this.code,
    required this.createdByUserId,
    required this.createdAt,
    this.expiresAt,
    this.maxUses,
    this.usedCount = 0,
  });


bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
bool get isDepleted => maxUses != null && usedCount >= maxUses!;


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


factory BaseInvite.fromMap(Map<String, dynamic> map) => BaseInvite(
  id: map['id'] as String,
  baseId: map['baseId'] as String,
  code: map['code'] as String,
  createdByUserId: map['createdByUserId'] as String,
  createdAt: DateTime.parse(map['createdAt'] as String),
  expiresAt: map['expiresAt'] != null ? DateTime.parse(map['expiresAt']) : null,
  maxUses: map['maxUses'] as int?,
  usedCount: (map['usedCount'] ?? 0) as int,
);


  String toJson() => json.encode(toMap());
  factory BaseInvite.fromJson(String source) => BaseInvite.fromMap(json.decode(source));
}