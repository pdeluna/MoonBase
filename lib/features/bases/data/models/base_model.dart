import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';

class BaseModel {
  const BaseModel({
    required this.id,
    required this.name,
    required this.ownerUserId,
    required this.createdAt,
    this.memberUids = const [],
  });

  factory BaseModel.fromMap(Map<String, dynamic> map) => BaseModel(
    id: map['id'] as String,
    name: map['name'] as String,
    ownerUserId: map['ownerUserId'] as String,
    createdAt: DateTime.parse(map['createdAt'] as String),
    memberUids: List<String>.from(
      (map['memberUids'] as List<dynamic>?) ?? const <dynamic>[],
    ),
  );

  /// Firestore `bases/{baseId}` → model. Doc id is [id]; cloud uses `ownerUid`.
  factory BaseModel.fromFirestore(String id, Map<String, dynamic> data) {
    final rawCreated = data['createdAt'];
    final createdAt = switch (rawCreated) {
      Timestamp ts => ts.toDate().toUtc(),
      DateTime dt => dt.toUtc(),
      _ => DateTime.now().toUtc(),
    };
    final rawMembers = data['memberUids'];
    final memberUids = rawMembers is List
        ? rawMembers.map((e) => e.toString()).toList()
        : <String>[];
    return BaseModel(
      id: id,
      name: data['name'] as String? ?? '',
      ownerUserId: data['ownerUid'] as String? ?? '',
      createdAt: createdAt,
      memberUids: memberUids,
    );
  }

  final String id;
  final String name;
  final String ownerUserId;
  final DateTime createdAt;

  /// Cloud membership list; not on domain [Base].
  final List<String> memberUids;

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
    'memberUids': memberUids,
  };

  /// Exactly the keys allowed by `firestore.rules` create `hasOnly`.
  Map<String, dynamic> toFirestore() => {
    'name': name,
    'ownerUid': ownerUserId,
    'memberUids': memberUids,
    'createdAt': Timestamp.fromDate(createdAt.toUtc()),
    'schemaVersion': 1,
  };
}
