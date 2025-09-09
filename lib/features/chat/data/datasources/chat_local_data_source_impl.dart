import 'dart:async';
import 'dart:math';
import '../models/message_model.dart';
import 'chat_local_data_source.dart';

/// DEV-ONLY in-memory messages; resets on hot restart.
class InMemoryChatLocalDataSource implements ChatLocalDataSource {
  final Map<String, List<MessageModel>> _byBase = {}; // baseId -> messages (newest last)
  final Map<String, StreamController<List<MessageModel>>> _controllers = {};

  String _genId() {
    final r = Random();
    return 'm_${DateTime.now().microsecondsSinceEpoch}_${r.nextInt(1 << 32)}';
  }

  StreamController<List<MessageModel>> _ctrl(String baseId) {
    return _controllers.putIfAbsent(
      baseId,
      () => StreamController<List<MessageModel>>.broadcast(onListen: () {
        // seed with current list
        _controllers[baseId]!.add(List<MessageModel>.unmodifiable(_byBase[baseId] ?? const <MessageModel>[]));
      }),
    );
  }

  void _emit(String baseId) {
    final list = List<MessageModel>.unmodifiable(_byBase[baseId] ?? const <MessageModel>[]);
    final c = _controllers[baseId];
    if (c != null && !c.isClosed) c.add(list);
  }

  @override
  Stream<List<MessageModel>> streamMessages(String baseId) => _ctrl(baseId).stream;

  @override
  Future<MessageModel> sendMessage({
    required String baseId,
    required String userId,
    required String content,
  }) async {
    final msg = MessageModel(
      id: _genId(),
      baseId: baseId,
      userId: userId,
      content: content,
      createdAt: DateTime.now(),
    );
    final list = _byBase.putIfAbsent(baseId, () => <MessageModel>[]);
    list.add(msg);
    // ensure newest last
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _emit(baseId);
    return msg;
  }

  @override
  Future<List<MessageModel>> listMessages({
    required String baseId,
    DateTime? before,
    int limit = 50,
  }) async {
    final list = List<MessageModel>.from(_byBase[baseId] ?? const []);
    // older-than pagination (newest last internally)
    final filtered = before == null
        ? list
        : list.where((m) => m.createdAt.isBefore(before)).toList();
    // return last N (oldest to newest)
    final start = filtered.length > limit ? filtered.length - limit : 0;
    return filtered.sublist(start);
  }
}
