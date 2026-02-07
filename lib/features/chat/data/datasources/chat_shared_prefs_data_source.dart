import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moonbase_skeleton/features/chat/data/models/message_model.dart';
import 'package:moonbase_skeleton/features/chat/data/datasources/chat_local_data_source.dart';

/// SharedPreferences-backed chat data source for the new architecture
/// Uses the same storage format as the legacy SpChatRepository
class ChatSharedPrefsDataSource implements ChatLocalDataSource {
  ChatSharedPrefsDataSource(this._prefs);
  
  static const _kMessages = 'mb.messages';
  static const _kMessageIds = 'mb.messageIds';

  final SharedPreferences _prefs;
  final Map<String, StreamController<List<MessageModel>>> _streamControllers = {};

  // ---- helpers ----

  Map<String, dynamic> _readMessages() {
    final raw = _prefs.getString(_kMessages);
    if (raw == null) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _writeMessages(Map<String, dynamic> messages) async {
    await _prefs.setString(_kMessages, jsonEncode(messages));
  }

  Map<String, dynamic> _readMessageIds() {
    final raw = _prefs.getString(_kMessageIds);
    if (raw == null) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _writeMessageIds(Map<String, dynamic> messageIds) async {
    await _prefs.setString(_kMessageIds, jsonEncode(messageIds));
  }

  // Notify stream listeners
  void _notifyStreamListeners(String baseId, List<MessageModel> messages) {
    developer.log('ChatSharedPrefsDataSource: Notifying stream listeners for base $baseId with ${messages.length} messages');
    final controller = _streamControllers[baseId];
    if (controller != null && !controller.isClosed) {
      controller.add(messages);
      developer.log('ChatSharedPrefsDataSource: Stream notification sent');
    } else {
      developer.log('ChatSharedPrefsDataSource: No active stream controller for base $baseId');
    }
  }

  // ---- ChatLocalDataSource implementation ----

  @override
  Future<MessageModel> sendMessage({
    required String baseId,
    required String userId,
    required String content,
  }) async {
    final messageId = 'm_${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now();
    
    final message = MessageModel(
      id: messageId,
      baseId: baseId,
      userId: userId,
      content: content,
      createdAt: now,
    );

    // Save message
    final messages = _readMessages();
    final baseMessages = List<Map<String, dynamic>>.from(
      (messages[baseId] ?? <Map<String, dynamic>>[]) as Iterable<dynamic>
    );
    baseMessages.add(message.toMap());
    messages[baseId] = baseMessages;
    await _writeMessages(messages);

    // Save message ID mapping
    final messageIds = _readMessageIds();
    messageIds[messageId] = baseId;
    await _writeMessageIds(messageIds);

    // Notify stream listeners
    final allMessages = await _getMessagesForBase(baseId);
    developer.log('ChatSharedPrefsDataSource: Message saved, notifying listeners with ${allMessages.length} total messages');
    _notifyStreamListeners(baseId, allMessages);

    return message;
  }

  @override
  Stream<List<MessageModel>> streamMessages(String baseId) {
    // Create stream controller if it doesn't exist
    if (!_streamControllers.containsKey(baseId)) {
      _streamControllers[baseId] = StreamController<List<MessageModel>>.broadcast();
      
      // Load initial messages
      _getMessagesForBase(baseId).then((messages) {
        final controller = _streamControllers[baseId];
        if (controller != null && !controller.isClosed) {
          controller.add(messages);
        }
      });
    }
    
    return _streamControllers[baseId]!.stream;
  }

  @override
  Future<List<MessageModel>> listMessages({
    required String baseId,
    DateTime? before,
    int limit = 50,
  }) async {
    final messages = await _getMessagesForBase(baseId);
    
    // Sort by creation date (newest first)
    messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    // Apply pagination
    if (before != null) {
      final beforeIndex = messages.indexWhere((m) => m.createdAt.isBefore(before));
      if (beforeIndex != -1) {
        // Get messages before the specified timestamp
        final startIndex = beforeIndex + 1;
        if (startIndex < messages.length) {
          messages.removeRange(startIndex, messages.length);
        } else {
          return []; // No more messages to load
        }
      }
    }
    
    // Limit results
    if (messages.length > limit) {
      messages.removeRange(limit, messages.length);
    }
    
    return messages;
  }

  // Helper method to get all messages for a base
  Future<List<MessageModel>> _getMessagesForBase(String baseId) async {
    final messages = _readMessages();
    final baseMessages = List<Map<String, dynamic>>.from(
      (messages[baseId] ?? <Map<String, dynamic>>[]) as Iterable<dynamic>
    );
    
    final result = <MessageModel>[];
    for (final messageJson in baseMessages) {
      try {
        final message = MessageModel.fromMap(messageJson);
        result.add(message);
      } catch (_) {
        // Skip corrupted message data
      }
    }
    
    return result;
  }

  // Dispose method to clean up stream controllers
  void dispose() {
    for (final controller in _streamControllers.values) {
      controller.close();
    }
    _streamControllers.clear();
  }
}
