import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/profile/domain/entities/profile.dart';

class ProfileModel {
  const ProfileModel({
    required this.userId,
    required this.nickname,
    this.avatarUrl,
    required this.updatedAt,
    this.themeMode = 'light',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? updatedAt;

  factory ProfileModel.fromMap(Map<String, dynamic> map) => ProfileModel(
    userId: map['userId'] as String,
    nickname: map['nickname'] as String,
    avatarUrl: map['avatarUrl'] as String?,
    updatedAt: DateTime.parse(map['updatedAt'] as String),
    themeMode: map['themeMode'] as String? ?? 'light',
    createdAt: map['createdAt'] != null
        ? DateTime.parse(map['createdAt'] as String)
        : DateTime.parse(map['updatedAt'] as String),
  );

  /// Firestore `users/{uid}` → model. Doc id is [userId]; cloud fields only.
  factory ProfileModel.fromFirestore(String userId, Map<String, dynamic> data) {
    final rawCreated = data['createdAt'];
    final createdAt = switch (rawCreated) {
      Timestamp ts => ts.toDate().toUtc(),
      DateTime dt => dt.toUtc(),
      _ => DateTime.now().toUtc(),
    };
    return ProfileModel(
      userId: userId,
      nickname: data['nickname'] as String? ?? '',
      avatarUrl: null,
      themeMode: data['themeMode'] as String? ?? 'light',
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  final String userId;
  final String nickname;
  final String? avatarUrl;
  final DateTime updatedAt;

  /// Prefs + Firestore round-trip. Not on domain [Profile].
  final String themeMode;

  /// Firestore `createdAt` (immutable after create). Not on domain [Profile].
  final DateTime createdAt;

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
    'themeMode': themeMode,
    'createdAt': createdAt.toIso8601String(),
  };

  /// Exactly the keys allowed by `firestore.rules` create/update `hasOnly`.
  Map<String, dynamic> toFirestore() => {
    'nickname': nickname,
    'themeMode': themeMode,
    'createdAt': Timestamp.fromDate(createdAt.toUtc()),
    'schemaVersion': 1,
  };

  ProfileModel copyWith({
    String? nickname,
    String? avatarUrl,
    DateTime? updatedAt,
    String? themeMode,
    DateTime? createdAt,
  }) {
    return ProfileModel(
      userId: userId,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      updatedAt: updatedAt ?? this.updatedAt,
      themeMode: themeMode ?? this.themeMode,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
