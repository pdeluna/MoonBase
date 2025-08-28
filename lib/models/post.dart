import 'dart:convert';
import 'media_ref.dart';


class BasePost {
  final String id; // uuid v4
  final String baseId;
  final String authorUserId;
  final String? text;
  final List<MediaRef> media; // images/videos/links
  final DateTime createdAt;
  final DateTime updatedAt;


  const BasePost({
    required this.id,
    required this.baseId,
    required this.authorUserId,
    this.text,
    this.media = const [],
    required this.createdAt,
    required this.updatedAt,
  });


  Map<String, dynamic> toMap() => {
    'id': id,
    'baseId': baseId,
    'authorUserId': authorUserId,
    'text': text,
    'media': media.map((m) => m.toMap()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };


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


  String toJson() => json.encode(toMap());
  factory BasePost.fromJson(String source) => BasePost.fromMap(json.decode(source));
}