import 'package:moonbase_skeleton/features/chat/data/models/message_model.dart';

/// One snapshot of messages plus whether it came from cache.
///
/// Firebase `SnapshotMetadata` stays in the Firestore data source.
/// [fromCache] is `snap.metadata.isFromCache` alone — do not AND
/// `hasPendingWrites`; pending local writes are not a freshness signal.
class ChatMessageBatch {
  const ChatMessageBatch({
    required this.messages,
    required this.fromCache,
    this.unacknowledgedIds = const <String>{},
  });

  final List<MessageModel> messages;
  final bool fromCache;

  /// Document ids whose local write the server has not acknowledged.
  ///
  /// Not a freshness signal — [fromCache] stays `isFromCache` alone.
  /// [ChatRepositoryImpl] drops these from the domain feed so a cache echo
  /// is not treated as delivery. The outbox owns them until the server acks.
  final Set<String> unacknowledgedIds;
}
