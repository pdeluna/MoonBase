import 'package:moonbase_skeleton/core/ids.dart';
class Message {
  const Message({
    required this.id,
    required this.baseId,
    required this.userId,
    required this.content,
    required this.createdAt,
  });

  final MessageId id;
  final BaseId baseId;
  final UserId userId;
  final String content;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message &&
        other.id == id &&
        other.baseId == baseId &&
        other.userId == userId &&
        other.content == content &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(id, baseId, userId, content, createdAt);
  }

  @override
  String toString() {
    return 'Message(id: $id, baseId: $baseId, userId: $userId, content: $content, createdAt: $createdAt)';
  }
}
