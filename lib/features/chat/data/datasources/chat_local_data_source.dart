import 'package:moonbase_skeleton/features/chat/data/models/chat_message_batch.dart';
import 'package:moonbase_skeleton/features/chat/data/models/message_model.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';

abstract class ChatLocalDataSource {
  Future<MessageModel> sendMessage({
    required String baseId,
    required String userId,
    required String content,
    List<MediaRef> media = const [],
  });

  Stream<ChatMessageBatch> streamMessages(String baseId);

  Future<List<MessageModel>> listMessages({
    required String baseId,
    DateTime? before,
    int limit = 50,
  });
}
