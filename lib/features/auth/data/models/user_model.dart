import 'package:moonbase_skeleton/features/auth/domain/entities/user.dart';

class UserModel {
  const UserModel({required this.id, required this.nickname});

  factory UserModel.fromMap(Map<String, dynamic> map) =>
      UserModel(id: map['id'] as String, nickname: map['nickname'] as String);

  final String id;
  final String nickname;

  User toEntity() => User(id: id, nickname: nickname);

  Map<String, dynamic> toMap() => {'id': id, 'nickname': nickname};
}
