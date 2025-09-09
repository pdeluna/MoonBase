import '../../domain/entities/user.dart';

class UserModel {
  final String id;
  final String nickname;

  const UserModel({required this.id, required this.nickname});

  User toEntity() => User(id: id, nickname: nickname);

  factory UserModel.fromMap(Map<String, dynamic> map) =>
      UserModel(id: map['id'] as String, nickname: map['nickname'] as String);

  Map<String, dynamic> toMap() => {'id': id, 'nickname': nickname};
}
