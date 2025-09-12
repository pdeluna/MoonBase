import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/usecase.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';
import 'package:moonbase_skeleton/features/chat/domain/repositories/chat_repository.dart';

class SendMessageParams {
  const SendMessageParams({required this.baseId, required this.userId, required this.content});

  final BaseId baseId;
  final UserId userId;
  final String content;
}

class SendMessage implements UseCase<Message, SendMessageParams> {
  const SendMessage(this.repo);

  final ChatRepository repo;

  @override
  Future<Either<Failure, Message>> call(SendMessageParams p) =>
      repo.sendMessage(baseId: p.baseId, userId: p.userId, content: p.content);
}
