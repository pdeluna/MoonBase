import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/chat_feed.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';

abstract class ChatRepository {
  /// Persist a new message in [baseId] authored by [userId].
  ///
  /// Phase 3 (Slice A) adds [media]: zero or more `MediaRef`s to attach.
  /// The list defaults to empty so all existing call sites compile without
  /// modification. Validation of the text+media payload (caps, "at least
  /// one of text or media" rule) lives in `SendMessage`, not here.
  ///
  /// [messageId] is the optional client-chosen id. The pending-send outbox
  /// mints one up front so a retry re-sends the **same** document id and the
  /// live feed can dedupe the local pending copy against the persisted doc.
  /// When null the data source generates a fresh id.
  Future<Either<Failure, Message>> sendMessage({
    required BaseId baseId,
    required UserId userId,
    required String content,
    List<MediaRef> media = const [],
    MessageId? messageId,
  });

  /// Live updates for a base's messages (newest last) plus cache-vs-live.
  Stream<ChatFeed> streamMessages(BaseId baseId);

  /// For initial load or pagination.
  Future<Either<Failure, List<Message>>> listMessages({
    required BaseId baseId,
    DateTime? before, // fetch older than this timestamp
    int limit = 50,
  });
}
