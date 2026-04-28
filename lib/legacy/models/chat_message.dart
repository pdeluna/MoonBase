import 'dart:convert';
import 'package:moonbase_skeleton/legacy/models/media_ref.dart';
import 'package:moonbase_skeleton/legacy/models/enums.dart';

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.baseId,
    required this.authorUserId,
    required this.type,
    this.text,
    this.media,
    required this.createdAt,
    this.editedAt,
    this.replyToMessageId,
    this.isEdited = false,
    this.isDeleted = false,
  });

    factory ChatMessage.fromJson(String source) => ChatMessage.fromMap(json.decode(source) as Map<String, dynamic>);

    factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
    id: map['id'] as String,
    baseId: map['baseId'] as String,
    authorUserId: map['authorUserId'] as String,
    type: MessageType.values.byName(map['type'] as String),
    text: map['text'] as String?,
    media: map['media'] != null 
      ? (map['media'] as List<dynamic>)
          .map((e) => MediaRef.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList()
      : null,
    createdAt: DateTime.parse(map['createdAt'] as String),
    editedAt: map['editedAt'] != null ? DateTime.parse(map['editedAt'] as String) : null,
    replyToMessageId: map['replyToMessageId'] as String?,
    isEdited: (map['isEdited'] ?? false) as bool,
    isDeleted: (map['isDeleted'] ?? false) as bool,
  );

  final String id; // uuid v4
  final String baseId;
  final String authorUserId;
  final MessageType type;
  final String? text;
  final List<MediaRef>? media;
  final DateTime createdAt;
  final DateTime? editedAt;
  final String? replyToMessageId; // for threaded replies
  final bool isEdited;
  final bool isDeleted;


  ChatMessage copyWith({
    String? id,
    String? baseId,
    String? authorUserId,
    MessageType? type,
    String? text,
    List<MediaRef>? media,
    DateTime? createdAt,
    DateTime? editedAt,
    String? replyToMessageId,
    bool? isEdited,
    bool? isDeleted,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      baseId: baseId ?? this.baseId,
      authorUserId: authorUserId ?? this.authorUserId,
      type: type ?? this.type,
      text: text, // Allow explicit null values
      media: media, // Allow explicit null values
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt, // Allow explicit null values
      replyToMessageId: replyToMessageId, // Allow explicit null values
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'baseId': baseId,
    'authorUserId': authorUserId,
    'type': type.name,
    'text': text,
    'media': media?.map((m) => m.toMap()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'editedAt': editedAt?.toIso8601String(),
    'replyToMessageId': replyToMessageId,
    'isEdited': isEdited,
    'isDeleted': isDeleted,
  };

  String toJson() => json.encode(toMap());

  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is ChatMessage &&
    runtimeType == other.runtimeType &&
    id == other.id;

  @override
  int get hashCode => id.hashCode;
}
