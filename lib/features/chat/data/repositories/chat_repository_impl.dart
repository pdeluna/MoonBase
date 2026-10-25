import 'dart:async';

import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/error_mapper.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/chat/data/datasources/chat_local_data_source.dart';
import 'package:moonbase_skeleton/features/chat/data/datasources/chat_remote_data_source.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/chat_feed.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/chat_freshness.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';
import 'package:moonbase_skeleton/features/chat/domain/repositories/chat_repository.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';

/// How long a chat send waits for a server ack before the outbox marks it
/// failed.
///
/// Shorter than [kGuardTimeout]. That 20s backstop exists because a cached
/// *read* was measured at 14.9s (`docs/RESILIENCE_DECISIONS.md`). A send ack
/// is one write; on the acceptance network the cache→live window is ~117ms.
/// Airplane mode queues the write in the local cache and the Future never
/// completes — without this bound the bubble would spin forever and no
/// Retry alert would appear. Profile create-or-return (trigger #12) stays
/// unbounded. If the queued write later acks, the live feed settles the
/// failed bubble.
const Duration kChatSendAckTimeout = Duration(seconds: 8);

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl({required this.local, this.remote});

  final ChatLocalDataSource local;
  final ChatRemoteDataSource? remote;

  @override
  Future<Either<Failure, Message>> sendMessage({
    required BaseId baseId,
    required UserId userId,
    required String content,
    List<MediaRef> media = const [],
    MessageId? messageId,
  }) =>
      guard(() async {
        final m = await local.sendMessage(
          baseId: baseId.value,
          userId: userId.value,
          content: content,
          media: media,
          messageId: messageId?.value,
        ).timeout(
          kChatSendAckTimeout,
          onTimeout: () => throw const NetworkFailure(
            'Chat send was not acknowledged by the server.',
          ),
        );
        return m.toEntity();
      });

  @override
  Future<Either<Failure, List<Message>>> listMessages({
    required BaseId baseId,
    DateTime? before,
    int limit = 50,
  }) =>
      guardWithTimeout(() async {
        final ms = await local.listMessages(
          baseId: baseId.value,
          before: before,
          limit: limit,
        );
        return ms.map((m) => m.toEntity()).toList();
      });

  @override
  Stream<ChatFeed> streamMessages(BaseId baseId) =>
      local.streamMessages(baseId.value).map((batch) {
        // Drop local echoes. A document with hasPendingWrites is not
        // delivery — the outbox bubble is the pending/failed UI. Counting
        // the echo as a feed message cleared that bubble and the cached
        // banner was the only thing left on screen (S1 B-c).
        final hidden = batch.unacknowledgedIds;
        final messages = batch.messages
            .where((m) => !hidden.contains(m.id))
            .map((m) => m.toEntity())
            .toList(growable: false);
        return ChatFeed(
          messages: messages,
          freshness:
              batch.fromCache ? ChatFreshness.cached : ChatFreshness.live,
        );
      });
}
