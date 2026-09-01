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
  });

  final List<MessageModel> messages;
  final bool fromCache;
}
