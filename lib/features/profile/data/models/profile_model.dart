import '../../domain/entities/profile.dart';

class ProfileModel {
  final String userId;
  final String nickname;
  final String? avatarUrl;
  final DateTime updatedAt;

  const ProfileModel({
    required this.userId,
    required this.nickname,
    this.avatarUrl,
    required this.updatedAt,
  });

  Profile toEntity() => Profile(
    userId: userId,
    nickname: nickname,
    avatarUrl: avatarUrl,
    updatedAt: updatedAt,
  );

  factory ProfileModel.fromMap(Map<String, dynamic> map) => ProfileModel(
    userId: map['userId'] as String,
    nickname: map['nickname'] as String,
    avatarUrl: map['avatarUrl'] as String?,
    updatedAt: DateTime.parse(map['updatedAt'] as String),
  );

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'nickname': nickname,
    'avatarUrl': avatarUrl,
    'updatedAt': updatedAt.toIso8601String(),
  };

  ProfileModel copyWith({String? nickname, String? avatarUrl, DateTime? updatedAt}) {
    return ProfileModel(
      userId: userId,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
