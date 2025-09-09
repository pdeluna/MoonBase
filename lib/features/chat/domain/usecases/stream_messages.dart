import '../entities/message.dart';
import '../repositories/chat_repository.dart';

class StreamMessages {
  final ChatRepository repo;
  const StreamMessages(this.repo);

  Stream<List<Message>> call(String baseId) => repo.streamMessages(baseId);
}
