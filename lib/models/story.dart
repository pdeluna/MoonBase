import 'dart:convert';
import 'package:moonbase_skeleton/models/media_ref.dart';


class BaseStory {
  const BaseStory({
  required this.id,
  required this.baseId,
  required this.authorUserId,
  required this.media,
  required this.ttl,
  required this.createdAt,
  });
  
  factory BaseStory.fromJson(String source) => BaseStory.fromMap(json.decode(source) as Map<String, dynamic>);

  factory BaseStory.fromMap(Map<String, dynamic> map) => BaseStory(
    id: map['id'] as String,
    baseId: map['baseId'] as String,
    authorUserId: map['authorUserId'] as String,
    media: MediaRef.fromMap(Map<String, dynamic>.from(map['media'] as Map)),
    ttl: Duration(milliseconds: (map['ttlMs'] ?? 86400000) as int),
    createdAt: DateTime.parse(map['createdAt'] as String),
  );

  final String id; // uuid v4
  final String baseId;
  final String authorUserId;
  final MediaRef media; // single media per story
  final Duration ttl; // time-to-live from createdAt
  final DateTime createdAt;

  bool get isExpired => DateTime.now().isAfter(createdAt.add(ttl));

  Map<String, dynamic> toMap() => {
    'id': id,
    'baseId': baseId,
    'authorUserId': authorUserId,
    'media': media.toMap(),
    'ttlMs': ttl.inMilliseconds,
    'createdAt': createdAt.toIso8601String(),
  };

  String toJson() => json.encode(toMap());
  }