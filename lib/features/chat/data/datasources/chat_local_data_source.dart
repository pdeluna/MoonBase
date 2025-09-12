import 'package:moonbase_skeleton/features/chat/data/models/message_model.dart';

abstract class ChatLocalDataSource {
  Future<MessageModel> sendMessage({
    required String baseId,
    required String userId,
    required String content,
  });

  Stream<List<MessageModel>> streamMessages(String baseId);

  Future<List<MessageModel>> listMessages({
    required String baseId,
    DateTime? before,
    int limit = 50,
  });
}
