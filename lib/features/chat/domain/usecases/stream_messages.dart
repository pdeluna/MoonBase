import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';
import 'package:moonbase_skeleton/features/chat/domain/repositories/chat_repository.dart';

class StreamMessages {
  const StreamMessages(this.repo);

  final ChatRepository repo;

  Stream<List<Message>> call(String baseId) => repo.streamMessages(baseId);
}
