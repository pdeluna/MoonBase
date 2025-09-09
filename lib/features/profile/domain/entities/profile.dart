class Profile {
  final String userId;
  final String nickname; // keep aligned with your app
  final String? avatarUrl;
  final DateTime updatedAt;

  const Profile({
    required this.userId,
    required this.nickname,
    this.avatarUrl,
    required this.updatedAt,
  });

  Profile copyWith({String? nickname, String? avatarUrl, DateTime? updatedAt}) {
    return Profile(
      userId: userId,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
