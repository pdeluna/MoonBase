import 'package:moonbase_skeleton/features/chat/data/models/chat_message_batch.dart';
import 'package:moonbase_skeleton/features/chat/data/models/message_model.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';

abstract class ChatLocalDataSource {
  /// [messageId] is the optional client-chosen doc id (outbox retry); when
  /// null the implementation generates one.
  Future<MessageModel> sendMessage({
    required String baseId,
    required String userId,
    required String content,
    List<MediaRef> media = const [],
    String? messageId,
  });

  Stream<ChatMessageBatch> streamMessages(String baseId);

  Future<List<MessageModel>> listMessages({
    required String baseId,
    DateTime? before,
    int limit = 50,
  });
}
