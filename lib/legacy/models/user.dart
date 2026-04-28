import 'dart:convert';

class User {
  const User({
    required this.id,
    required this.email,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.isEmailVerified = false,
    required this.createdAt,
    required this.updatedAt,
    this.lastSeenAt,
    this.isActive = true,
    this.baseIds = const [],
  });

  factory User.fromMap(Map<String, dynamic> map) => User(
    id: map['id'] as String,
    email: map['email'] as String,
    username: map['username'] as String,
    displayName: map['displayName'] as String?,
    avatarUrl: map['avatarUrl'] as String?,
    isEmailVerified: (map['isEmailVerified'] ?? false) as bool,
    createdAt: DateTime.parse(map['createdAt'] as String),
    updatedAt: DateTime.parse(map['updatedAt'] as String),
    lastSeenAt: map['lastSeenAt'] != null ? DateTime.parse(map['lastSeenAt'] as String) : null,
    isActive: (map['isActive'] ?? true) as bool,
    baseIds: List<String>.from((map['baseIds'] ?? const <String>[]) as Iterable<dynamic>),
  );

  factory User.fromJson(String source) => User.fromMap(json.decode(source) as Map<String, dynamic>);

  final String id; // uuid v4
  final String email;
  final String username; // unique, case-insensitive
  final String? displayName;
  final String? avatarUrl;
  final bool isEmailVerified;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastSeenAt;
  final bool isActive;
  final List<String> baseIds; // bases this user is a member of

  User copyWith({
    String? id,
    String? email,
    String? username,
    String? displayName,
    String? avatarUrl,
    bool? isEmailVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastSeenAt,
    bool? isActive,
    List<String>? baseIds,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      isActive: isActive ?? this.isActive,
      baseIds: baseIds ?? this.baseIds,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'email': email,
    'username': username,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
    'isEmailVerified': isEmailVerified,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'lastSeenAt': lastSeenAt?.toIso8601String(),
    'isActive': isActive,
    'baseIds': baseIds,
  };

  String toJson() => json.encode(toMap());

  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is User &&
    runtimeType == other.runtimeType &&
    id == other.id;

  @override
  int get hashCode => id.hashCode;
}
