import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';
import 'package:moonbase_skeleton/core/ids.dart';

class MessageModel {
  const MessageModel({
    required this.id,
    required this.baseId,
    required this.userId,
    required this.content,
    required this.createdAt,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) => MessageModel(
    id: map['id'] as String,
    baseId: map['baseId'] as String,
    userId: map['userId'] as String,
    content: map['content'] as String,
    createdAt: DateTime.parse(map['createdAt'] as String),
  );

  final String id;
  final String baseId;
  final String userId;
  final String content;
  final DateTime createdAt;


  Message toEntity() => Message(
    id: id.mid,
    baseId: baseId.bid,
    userId: userId.uid,
    content: content,
    createdAt: createdAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'baseId': baseId,
    'userId': userId,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
  };
}
