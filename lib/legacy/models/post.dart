import 'dart:convert';
import 'package:moonbase_skeleton/legacy/models/media_ref.dart';


class BasePost {
  const BasePost({
    required this.id,
    required this.baseId,
    required this.authorUserId,
    this.text,
    this.media = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory BasePost.fromJson(String source) => BasePost.fromMap(json.decode(source) as Map<String, dynamic>);

  factory BasePost.fromMap(Map<String, dynamic> map) => BasePost(
    id: map['id'] as String,
    baseId: map['baseId'] as String,
    authorUserId: map['authorUserId'] as String,
    text: map['text'] as String?,
    media: (map['media'] as List<dynamic>? ?? const [])
    .map((e) => MediaRef.fromMap(Map<String, dynamic>.from(e as Map)))
    .toList(),
    createdAt: DateTime.parse(map['createdAt'] as String),
    updatedAt: DateTime.parse(map['updatedAt'] as String),
    );

  final String id; // uuid v4
  final String baseId;
  final String authorUserId;
  final String? text;
  final List<MediaRef> media; // images/videos/links
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() => {
    'id': id,
    'baseId': baseId,
    'authorUserId': authorUserId,
    'text': text,
    'media': media.map((m) => m.toMap()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  String toJson() => json.encode(toMap());
}