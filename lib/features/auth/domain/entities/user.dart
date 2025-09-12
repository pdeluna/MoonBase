import 'package:moonbase_skeleton/core/ids.dart';

class User {
  const User({required this.id, required this.nickname});

  final UserId id;
  final String nickname;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.id == id &&
        other.nickname == nickname;
  }

  @override
  int get hashCode {
    return Object.hash(id, nickname);
  }

  @override
  String toString() {
    return 'User(id: $id, nickname: $nickname)';
  }
}