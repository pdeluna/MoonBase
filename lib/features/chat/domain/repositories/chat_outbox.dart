import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';

/// Device-local outbox for chat messages that have not been acknowledged by
/// the backend yet.
///
/// A message enters the outbox the moment the user taps send (with
/// `SyncStatus.uploading`) and leaves it when the send use case returns
/// `Right`, or when the live feed delivers a server-acknowledged document
/// with the same id. A local cache echo is not in that feed.
/// Failed sends stay in the outbox as `SyncStatus.failed` so they survive
/// app termination and are replayed on the next open of that base.
///
/// This is a persistence port only — there are no business rules to hide
/// behind a use case, so `ChatController` drives it directly. Entries are
/// full [Message] values (client-chosen id, staged media keys) because a
/// retry must re-send exactly what the user composed.
abstract class ChatOutbox {
  /// Every queued message on this device, oldest first. Callers filter by
  /// base and by the signed-in user — entries authored by another account
  /// on the same device must never be replayed under the wrong session.
  Future<Either<Failure, List<Message>>> loadAll();

  /// Insert or replace the entry with [message]'s id.
  Future<Either<Failure, void>> upsert(Message message);

  /// Remove the entry with [id]; a no-op when absent.
  Future<Either<Failure, void>> remove(MessageId id);
}
