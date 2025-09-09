import '../../domain/entities/session.dart';

class SessionModel {
  final String userId;
  final DateTime createdAt;

  const SessionModel({required this.userId, required this.createdAt});

  Session toEntity() => Session(userId: userId, createdAt: createdAt);
}
