import 'package:moonbase_skeleton/features/profile/domain/entities/profile.dart';
import 'package:moonbase_skeleton/core/ids.dart';

class ProfileModel {
  const ProfileModel({
    required this.userId,
    required this.nickname,
    this.avatarUrl,
    required this.updatedAt,
  });

  factory ProfileModel.fromMap(Map<String, dynamic> map) => ProfileModel(
    userId: map['userId'] as String,
    nickname: map['nickname'] as String,
    avatarUrl: map['avatarUrl'] as String?,
    updatedAt: DateTime.parse(map['updatedAt'] as String),
  );

  final String userId;
  final String nickname;
  final String? avatarUrl;
  final DateTime updatedAt;

  Profile toEntity() => Profile(
    userId: userId.uid,
    nickname: nickname,
    avatarUrl: avatarUrl,
    updatedAt: updatedAt,
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
