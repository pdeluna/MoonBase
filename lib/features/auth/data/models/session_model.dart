import 'package:moonbase_skeleton/features/auth/domain/entities/session.dart';

class SessionModel {
  const SessionModel({required this.userId, required this.createdAt});

  final String userId;
  final DateTime createdAt;

  Session toEntity() => Session(userId: userId, createdAt: createdAt);
}
