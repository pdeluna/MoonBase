import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/core/ids.dart';

class BaseModel {
  const BaseModel({
    required this.id,
    required this.name,
    required this.ownerUserId,
    required this.createdAt,
  });

  factory BaseModel.fromMap(Map<String, dynamic> map) => BaseModel(
    id: map['id'] as String,
    name: map['name'] as String,
    ownerUserId: map['ownerUserId'] as String,
    createdAt: DateTime.parse(map['createdAt'] as String),
  );

  final String id;
  final String name;
  final String ownerUserId;
  final DateTime createdAt;

  Base toEntity() => Base(
    id: id.bid,
    name: name,
    ownerUserId: ownerUserId.uid,
    createdAt: createdAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'ownerUserId': ownerUserId,
    'createdAt': createdAt.toIso8601String(),
  };
}
