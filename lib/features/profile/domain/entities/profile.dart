class Profile {
  const Profile({
    required this.userId,
    required this.nickname,
    this.avatarUrl,
    required this.updatedAt,
  });

  final String userId;
  final String nickname; // keep aligned with your app
  final String? avatarUrl;
  final DateTime updatedAt;

  Profile copyWith({String? nickname, String? avatarUrl, DateTime? updatedAt}) {
    return Profile(
      userId: userId,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Profile &&
        other.userId == userId &&
        other.nickname == nickname &&
        other.avatarUrl == avatarUrl &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(userId, nickname, avatarUrl, updatedAt);
  }

  @override
  String toString() {
    return 'Profile(userId: $userId, nickname: $nickname, avatarUrl: $avatarUrl, updatedAt: $updatedAt)';
  }
}
