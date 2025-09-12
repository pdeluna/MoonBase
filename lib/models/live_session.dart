import 'dart:convert';
import 'package:moonbase_skeleton/models/enums.dart';


class LiveSession {
  const LiveSession({
  required this.id,
  required this.baseId,
  required this.hostUserId,
  required this.status,
  required this.createdAt,
  this.startedAt,
  this.endedAt,
  });

  factory LiveSession.fromJson(String source) => LiveSession.fromMap(json.decode(source) as Map<String, dynamic>);


  factory LiveSession.fromMap(Map<String, dynamic> map) => LiveSession(
    id: map['id'] as String,
    baseId: map['baseId'] as String,
    hostUserId: map['hostUserId'] as String,
    status: LiveStatus.values.byName(map['status'] as String),
    createdAt: DateTime.parse(map['createdAt'] as String),
    startedAt: map['startedAt'] != null ? DateTime.parse(map['startedAt'] as String) : null,
    endedAt: map['endedAt'] != null ? DateTime.parse(map['endedAt'] as String) : null,
  );

  final String id; // uuid v4
  final String baseId;
  final String hostUserId;
  final LiveStatus status; // scheduled, live, ended
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;

  Map<String, dynamic> toMap() => {
    'id': id,
    'baseId': baseId,
    'hostUserId': hostUserId,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'startedAt': startedAt?.toIso8601String(),
    'endedAt': endedAt?.toIso8601String(),
  };

  String toJson() => json.encode(toMap());
}