import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';

abstract class ChatRepository {
  Future<Either<Failure, Message>> sendMessage({
    required BaseId baseId,
    required UserId userId,
    required String content,
  });

  /// Live updates for a base's messages (newest last).
  Stream<List<Message>> streamMessages(BaseId baseId);

  /// For initial load or pagination.
  Future<Either<Failure, List<Message>>> listMessages({
    required BaseId baseId,
    DateTime? before, // fetch older than this timestamp
    int limit = 50,
  });
}
