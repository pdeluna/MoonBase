class Message {
  final String id;
  final String baseId;
  final String userId;
  final String content;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.baseId,
    required this.userId,
    required this.content,
    required this.createdAt,
  });
}
