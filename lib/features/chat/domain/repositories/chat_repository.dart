import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';

abstract class ChatRepository {
  /// Persist a new message in [baseId] authored by [userId].
  ///
  /// Phase 3 (Slice A) adds [media]: zero or more `MediaRef`s to attach.
  /// The list defaults to empty so all existing call sites compile without
  /// modification. Validation of the text+media payload (caps, "at least
  /// one of text or media" rule) lives in `SendMessage`, not here.
  Future<Either<Failure, Message>> sendMessage({
    required BaseId baseId,
    required UserId userId,
    required String content,
    List<MediaRef> media = const [],
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
