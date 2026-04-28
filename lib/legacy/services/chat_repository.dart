import 'package:moonbase_skeleton/legacy/models/chat_message.dart';
import 'package:moonbase_skeleton/legacy/models/enums.dart';
import 'package:moonbase_skeleton/legacy/models/media_ref.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:async';

abstract class ChatRepository {
  /// Send a new message to a base
  Future<ChatMessage> sendMessage({
    required String baseId,
    required String authorUserId,
    required MessageType type,
    String? text,
    List<String>? mediaUrls,
    String? replyToMessageId,
  });

  /// Get messages for a specific base, with pagination
  Future<List<ChatMessage>> getMessages({
    required String baseId,
    int limit = 50,
    String? beforeMessageId,
  });

  /// Stream messages for a specific base (real-time updates)
  Stream<List<ChatMessage>> streamMessages({
    required String baseId,
    int limit = 50,
  });

  /// Edit a message
  Future<ChatMessage> editMessage({
    required String messageId,
    required String newText,
  });

  /// Delete a message (soft delete)
  Future<void> deleteMessage(String messageId);

  /// Get a single message by ID
  Future<ChatMessage?> getMessage(String messageId);
}

/// SharedPreferences-backed repository for chat messages
/// Structure:
/// - mb.messages    : JSON object { baseId : [<ChatMessage JSON>] }
/// - mb.messageIds  : JSON object { messageId : baseId }
class SpChatRepository implements ChatRepository {
  static const _kMessages = 'mb.messages';
  static const _kMessageIds = 'mb.messageIds';

  // Stream controllers for real-time updates
  final Map<String, StreamController<List<ChatMessage>>> _streamControllers = {};

  // ---- helpers ----

  Future<Map<String, dynamic>> _readMessages(SharedPreferences sp) async {
    final raw = sp.getString(_kMessages);
    if (raw == null) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _writeMessages(SharedPreferences sp, Map<String, dynamic> messages) async {
    await sp.setString(_kMessages, jsonEncode(messages));
  }

  Future<Map<String, dynamic>> _readMessageIds(SharedPreferences sp) async {
    final raw = sp.getString(_kMessageIds);
    if (raw == null) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _writeMessageIds(SharedPreferences sp, Map<String, dynamic> messageIds) async {
    await sp.setString(_kMessageIds, jsonEncode(messageIds));
  }

  // Notify stream listeners
  void _notifyStreamListeners(String baseId, List<ChatMessage> messages) {
    final controller = _streamControllers[baseId];
    if (controller != null && !controller.isClosed) {
      controller.add(messages);
    }
  }

  // ---- ChatRepository implementation ----

  @override
  Future<ChatMessage> sendMessage({
    required String baseId,
    required String authorUserId,
    required MessageType type,
    String? text,
    List<String>? mediaUrls,
    String? replyToMessageId,
  }) async {
    final sp = await SharedPreferences.getInstance();
    
    final messageId = const Uuid().v4();
    final now = DateTime.now();
    
    // Convert mediaUrls to MediaRef objects
    List<MediaRef>? media;
    if (mediaUrls != null && mediaUrls.isNotEmpty) {
      media = mediaUrls.map((url) => MediaRef(
        id: const Uuid().v4(),
        uri: url,
        type: MediaType.image, // Default to image for now
      )).toList();
    }

    final message = ChatMessage(
      id: messageId,
      baseId: baseId,
      authorUserId: authorUserId,
      type: type,
      text: text,
      media: media,
      createdAt: now,
      replyToMessageId: replyToMessageId,
    );

    // Save message
    final messages = await _readMessages(sp);
    final baseMessages = List<Map<String, dynamic>>.from((messages[baseId] ?? <Map<String, dynamic>>[]) as Iterable<dynamic>);
    baseMessages.add(message.toMap());
    messages[baseId] = baseMessages;
    await _writeMessages(sp, messages);

    // Save message ID mapping
    final messageIds = await _readMessageIds(sp);
    messageIds[messageId] = baseId;
    await _writeMessageIds(sp, messageIds);

    // Notify stream listeners
    final allMessages = await _getMessagesForBase(baseId);
    _notifyStreamListeners(baseId, allMessages);

    return message;
  }

  @override
  Future<List<ChatMessage>> getMessages({
    required String baseId,
    int limit = 50,
    String? beforeMessageId,
  }) async {
    final messages = await _getMessagesForBase(baseId);
    
    // Sort by creation date (newest first)
    messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    // Apply pagination
    if (beforeMessageId != null) {
      final beforeIndex = messages.indexWhere((m) => m.id == beforeMessageId);
      if (beforeIndex != -1) {
        // Get messages before the specified message ID
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

  @override
  Stream<List<ChatMessage>> streamMessages({
    required String baseId,
    int limit = 50,
  }) {
    // Create stream controller if it doesn't exist
    if (!_streamControllers.containsKey(baseId)) {
      _streamControllers[baseId] = StreamController<List<ChatMessage>>.broadcast();
      
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
  Future<ChatMessage> editMessage({
    required String messageId,
    required String newText,
  }) async {
    final sp = await SharedPreferences.getInstance();
    
    // Get message
    final message = await getMessage(messageId);
    if (message == null) {
      throw Exception('Message not found');
    }

    // Create updated message
    final updatedMessage = message.copyWith(
      text: newText,
      editedAt: DateTime.now(),
      isEdited: true,
    );

    // Update in storage
    final messages = await _readMessages(sp);
    final baseMessages = List<Map<String, dynamic>>.from((messages[message.baseId] ?? <Map<String, dynamic>>[]) as Iterable<dynamic>);
    final messageIndex = baseMessages.indexWhere((m) => m['id'] == messageId);
    
    if (messageIndex != -1) {
      baseMessages[messageIndex] = updatedMessage.toMap();
      messages[message.baseId] = baseMessages;
      await _writeMessages(sp, messages);

      // Notify stream listeners
      final allMessages = await _getMessagesForBase(message.baseId);
      _notifyStreamListeners(message.baseId, allMessages);
    }

    return updatedMessage;
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    final sp = await SharedPreferences.getInstance();
    
    // Get message
    final message = await getMessage(messageId);
    if (message == null) {
      throw Exception('Message not found');
    }

    // Soft delete by marking as deleted
    final deletedMessage = message.copyWith(
      isDeleted: true,
      text: null, // Clear text for deleted messages
    );

    // Update in storage
    final messages = await _readMessages(sp);
    final baseMessages = List<Map<String, dynamic>>.from((messages[message.baseId] ?? <Map<String, dynamic>>[]) as Iterable<dynamic>);
    final messageIndex = baseMessages.indexWhere((m) => m['id'] == messageId);
    
    if (messageIndex != -1) {
      baseMessages[messageIndex] = deletedMessage.toMap();
      messages[message.baseId] = baseMessages;
      await _writeMessages(sp, messages);

      // Notify stream listeners
      final allMessages = await _getMessagesForBase(message.baseId);
      _notifyStreamListeners(message.baseId, allMessages);
    }
  }

  @override
  Future<ChatMessage?> getMessage(String messageId) async {
    final sp = await SharedPreferences.getInstance();
    final messageIds = await _readMessageIds(sp);
    final baseId = messageIds[messageId];
    
    if (baseId == null) return null;

    final messages = await _readMessages(sp);
    final baseMessages = List<Map<String, dynamic>>.from((messages[baseId] ?? <Map<String, dynamic>>[]) as Iterable<dynamic>);
    
    for (final messageJson in baseMessages) {
      if (messageJson['id'] == messageId) {
        try {
          return ChatMessage.fromMap(messageJson);
        } catch (_) {
          return null;
        }
      }
    }
    
    return null;
  }

  // Helper method to get all messages for a base
  Future<List<ChatMessage>> _getMessagesForBase(String baseId) async {
    final sp = await SharedPreferences.getInstance();
    final messages = await _readMessages(sp);
    final baseMessages = List<Map<String, dynamic>>.from((messages[baseId] ?? <Map<String, dynamic>>[]) as Iterable<dynamic>);
    
    final result = <ChatMessage>[];
    for (final messageJson in baseMessages) {
      try {
        final message = ChatMessage.fromMap(messageJson);
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
