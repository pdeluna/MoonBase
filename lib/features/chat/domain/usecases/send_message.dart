import '../../../../core/either.dart';
import '../../../../core/failure.dart';
import '../../../../core/usecase.dart';
import '../entities/message.dart';
import '../repositories/chat_repository.dart';

class SendMessageParams {
  final String baseId;
  final String userId;
  final String content;
  const SendMessageParams({required this.baseId, required this.userId, required this.content});
}

class SendMessage implements UseCase<Message, SendMessageParams> {
  final ChatRepository repo;
  const SendMessage(this.repo);

  @override
  Future<Either<Failure, Message>> call(SendMessageParams p) =>
      repo.sendMessage(baseId: p.baseId, userId: p.userId, content: p.content);
}
