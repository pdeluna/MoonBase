import '../../../../core/either.dart';
import '../../../../core/failure.dart';
import '../entities/message.dart';

abstract class ChatRepository {
  Future<Either<Failure, Message>> sendMessage({
    required String baseId,
    required String userId,
    required String content,
  });

  /// Live updates for a base's messages (newest last).
  Stream<List<Message>> streamMessages(String baseId);

  /// For initial load or pagination.
  Future<Either<Failure, List<Message>>> listMessages({
    required String baseId,
    DateTime? before, // fetch older than this timestamp
    int limit = 50,
  });
}
