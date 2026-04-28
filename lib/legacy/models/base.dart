import 'dart:convert'; 
//import 'media_ref.dart';
//import 'enums.dart';

class Base {
  const Base({
    required this.id,
    required this.name,
    required this.ownerUserId,
    this.description,
    this.memberIds = const [],
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
    this.lastAccessedAt,
  });

  factory Base.fromMap(Map<String, dynamic> map) {
    return Base(
      id: map['id'] as String,
      name: map['name'] as String,
      ownerUserId: map['ownerUserId'] as String,
      description: map['description'] as String?,
      memberIds: List<String>.from((map['memberIds'] ?? const <String>[]) as Iterable<dynamic>),
      avatarUrl: map['avatarUrl'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      lastAccessedAt: map['lastAccessedAt'] != null ? DateTime.parse(map['lastAccessedAt'] as String) : null,
    );
  }

  factory Base.fromJson(String source) => Base.fromMap(json.decode(source) as Map<String, dynamic>);

  final String id; // uuid v4
  final String name;
  final String ownerUserId;
  final String? description;
  final List<String> memberIds;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastAccessedAt;

  String toJson() => json.encode(toMap());

  Base copyWith({
  String? id,
  String? name,
  String? ownerUserId,
  String? description,
  List<String>? memberIds,
  String? avatarUrl,
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? lastAccessedAt,
}) {
  return Base(
    id: id ?? this.id,
    name: name ?? this.name,
    ownerUserId: ownerUserId ?? this.ownerUserId,
    description: description ?? this.description,
    memberIds: memberIds ?? this.memberIds,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
  );
}

Map<String, dynamic> toMap() {
  return {
    'id': id,
    'name': name,
    'ownerUserId': ownerUserId,
    'description': description,
    'memberIds': memberIds,
    'avatarUrl': avatarUrl,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'lastAccessedAt': lastAccessedAt?.toIso8601String(),
  };
}

@override
bool operator ==(Object other) =>
  identical(this, other) ||
  other is Base &&
  runtimeType == other.runtimeType &&
  id == other.id;

@override
int get hashCode => id.hashCode;
}

