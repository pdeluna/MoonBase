class Profile {
  const Profile({
    required this.userId,
    required this.nickname,
    required this.createdAt,
    required this.themeMode,
  });

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    userId: j['userId'] as String,
    nickname: j['nickname'] as String,
    createdAt: j['createdAt'] as String,
    themeMode: j['themeMode'] as String,
  );

  final String userId;     // uuid v4
  final String nickname;   // 2–24 chars
  final String createdAt;  // ISO-8601
  final String themeMode; // "light" or "dark"

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'nickname': nickname,
    'createdAt': createdAt,
    'version': 1, // future-proofing
    'themeMode': themeMode,
  };
}
