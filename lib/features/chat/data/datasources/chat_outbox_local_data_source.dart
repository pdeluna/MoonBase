import 'package:moonbase_skeleton/features/chat/data/models/message_model.dart';

/// Device-local storage for unacknowledged chat sends (see `ChatOutbox`).
///
/// Implementations throw on I/O problems; `ChatOutboxRepositoryImpl` wraps
/// every call in `guard` so failures reach callers as `Left(Failure)`.
abstract class ChatOutboxLocalDataSource {
  /// All queued entries, oldest first (insertion order).
  Future<List<MessageModel>> loadAll();

  /// Insert or replace by [MessageModel.id].
  Future<void> upsert(MessageModel message);

  /// Remove by id; no-op when absent.
  Future<void> remove(String messageId);
}
