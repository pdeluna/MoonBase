import 'package:moonbase_skeleton/features/chat/data/datasources/chat_outbox_local_data_source.dart';
import 'package:moonbase_skeleton/features/chat/data/models/message_model.dart';

/// DEV/TEST-ONLY in-memory outbox; resets on hot restart. Mirrors
/// `InMemoryChatLocalDataSource`.
class InMemoryChatOutboxDataSource implements ChatOutboxLocalDataSource {
  final List<MessageModel> _rows = <MessageModel>[];

  /// Current contents (unmodifiable) for assertions in tests.
  List<MessageModel> get rows => List<MessageModel>.unmodifiable(_rows);

  @override
  Future<List<MessageModel>> loadAll() async =>
      List<MessageModel>.unmodifiable(_rows);

  @override
  Future<void> upsert(MessageModel message) async {
    final index = _rows.indexWhere((r) => r.id == message.id);
    if (index == -1) {
      _rows.add(message);
    } else {
      _rows[index] = message;
    }
  }

  @override
  Future<void> remove(String messageId) async {
    _rows.removeWhere((r) => r.id == messageId);
  }
}
