class Session {
  const Session({required this.userId, required this.createdAt});

  final String userId;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Session &&
        other.userId == userId &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(userId, createdAt);
  }

  @override
  String toString() {
    return 'Session(userId: $userId, createdAt: $createdAt)';
  }
}