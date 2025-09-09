import '../../domain/entities/base.dart';

class BaseModel {
  final String id;
  final String name;
  final String ownerUserId;
  final DateTime createdAt;

  const BaseModel({
    required this.id,
    required this.name,
    required this.ownerUserId,
    required this.createdAt,
  });

  Base toEntity() => Base(
    id: id,
    name: name,
    ownerUserId: ownerUserId,
    createdAt: createdAt,
  );

  factory BaseModel.fromMap(Map<String, dynamic> map) => BaseModel(
    id: map['id'] as String,
    name: map['name'] as String,
    ownerUserId: map['ownerUserId'] as String,
    createdAt: DateTime.parse(map['createdAt'] as String),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'ownerUserId': ownerUserId,
    'createdAt': createdAt.toIso8601String(),
  };
}
