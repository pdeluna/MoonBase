import 'dart:convert';
import 'package:moonbase_skeleton/models/enums.dart';


class BaseMember {
  const BaseMember({
    required this.id,
    required this.baseId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    required this.updatedAt,
  });

  factory BaseMember.fromMap(Map<String, dynamic> map) => BaseMember(
    id: map['id'] as String,
    baseId: map['baseId'] as String,
    userId: map['userId'] as String,
    role: BaseRole.values.byName(map['role'] as String),
    joinedAt: DateTime.parse(map['joinedAt'] as String),
    updatedAt: DateTime.parse(map['updatedAt'] as String),
  );

  factory BaseMember.fromJson(String source) => BaseMember.fromMap(json.decode(source) as Map<String, dynamic>);

  final String id; // uuid v4
  final String baseId;
  final String userId;
  final BaseRole role; // owner/admin/member
  final DateTime joinedAt;
  final DateTime updatedAt;

  BaseMember copyWith({
    String? id,
    String? baseId,
    String? userId,
    BaseRole? role,
    DateTime? joinedAt,
    DateTime? updatedAt,
  }) {
    return BaseMember(
      id: id ?? this.id,
      baseId: baseId ?? this.baseId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'baseId': baseId,
    'userId': userId,
    'role': role.name,
    'joinedAt': joinedAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  String toJson() => json.encode(toMap());
}