import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/chat_feed.dart';
import 'package:moonbase_skeleton/features/chat/domain/repositories/chat_repository.dart';

class StreamMessages {
  const StreamMessages(this.repo);

  final ChatRepository repo;

  Stream<ChatFeed> call(BaseId baseId) => repo.streamMessages(baseId);
}
