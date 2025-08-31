import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/models/chat_message.dart';
import 'package:moonbase_skeleton/models/enums.dart';
import 'package:moonbase_skeleton/models/base.dart';
import 'package:moonbase_skeleton/services/chat_repository.dart';
import 'package:moonbase_skeleton/services/session_controller.dart';
import 'package:moonbase_skeleton/providers/bases_provider.dart';

// Repository provider
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return SpChatRepository();
});

// Chat messages provider - manages messages for a specific base
final chatMessagesProvider = StateNotifierProvider.family<ChatMessagesNotifier, AsyncValue<List<ChatMessage>>, String>((ref, baseId) {
  final repository = ref.watch(chatRepositoryProvider);
  final session = ref.watch(sessionProvider);
  return ChatMessagesNotifier(repository, session, baseId);
});

// Chat stream provider - provides real-time message updates for a specific base
final chatStreamProvider = StreamProvider.family<List<ChatMessage>, String>((ref, baseId) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.streamMessages(baseId: baseId);
});

// Chat actions provider - manages sending, editing, and deleting messages
final chatActionsProvider = StateNotifierProvider<ChatActionsNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(chatRepositoryProvider);
  final session = ref.watch(sessionProvider);
  final selectedBase = ref.watch(effectiveSelectedBaseProvider);
  
  return ChatActionsNotifier(repository, session, selectedBase);
});

class ChatMessagesNotifier extends StateNotifier<AsyncValue<List<ChatMessage>>> {
  ChatMessagesNotifier(this._repository, this._session, this._baseId) 
    : super(const AsyncValue.loading()) {
    _loadMessages();
  }

  final ChatRepository _repository;
  final AsyncValue<dynamic> _session;
  final String _baseId;
  StreamSubscription<List<ChatMessage>>? _streamSubscription;

  Future<void> _loadMessages() async {
    if (_session.value == null) {
      state = const AsyncValue.data([]);
      return;
    }

    try {
      state = const AsyncValue.loading();
      final messages = await _repository.getMessages(baseId: _baseId);
      state = AsyncValue.data(messages);
      
      // Start listening to real-time updates
      _startStreaming();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _startStreaming() {
    _streamSubscription?.cancel();
    _streamSubscription = _repository.streamMessages(baseId: _baseId).listen(
      (messages) {
        if (state.hasValue) {
          state = AsyncValue.data(messages);
        }
      },
      onError: (e, st) {
        if (state.hasValue) {
          state = AsyncValue.error(e, st);
        }
      },
    );
  }

  Future<void> loadMoreMessages({String? beforeMessageId}) async {
    if (_session.value == null) return;

    try {
      final currentMessages = state.value ?? [];
      final olderMessages = await _repository.getMessages(
        baseId: _baseId,
        beforeMessageId: beforeMessageId,
      );
      
      // Combine messages, avoiding duplicates
      final allMessages = [...olderMessages, ...currentMessages];
      final uniqueMessages = <ChatMessage>[];
      final seenIds = <String>{};
      
      for (final message in allMessages) {
        if (!seenIds.contains(message.id)) {
          seenIds.add(message.id);
          uniqueMessages.add(message);
        }
      }
      
      state = AsyncValue.data(uniqueMessages);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await _loadMessages();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }
}

class ChatActionsNotifier extends StateNotifier<AsyncValue<void>> {
  ChatActionsNotifier(this._repository, this._session, this._selectedBase) 
    : super(const AsyncValue.data(null));

  final ChatRepository _repository;
  final AsyncValue<dynamic> _session;
  final Base? _selectedBase;

  Future<ChatMessage> sendMessage({
    required MessageType type,
    String? text,
    List<String>? mediaUrls,
    String? replyToMessageId,
  }) async {
    if (_session.value == null) {
      throw Exception('User not authenticated');
    }

    if (_selectedBase == null) {
      throw Exception('No base selected');
    }

    try {
      state = const AsyncValue.loading();
      final message = await _repository.sendMessage(
        baseId: _selectedBase.id,
        authorUserId: _session.value!.userId,
        type: type,
        text: text,
        mediaUrls: mediaUrls,
        replyToMessageId: replyToMessageId,
      );
      state = const AsyncValue.data(null);
      return message;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<ChatMessage> editMessage({
    required String messageId,
    required String newText,
  }) async {
    if (_session.value == null) {
      throw Exception('User not authenticated');
    }

    try {
      state = const AsyncValue.loading();
      final message = await _repository.editMessage(
        messageId: messageId,
        newText: newText,
      );
      state = const AsyncValue.data(null);
      return message;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteMessage(String messageId) async {
    if (_session.value == null) {
      throw Exception('User not authenticated');
    }

    try {
      state = const AsyncValue.loading();
      await _repository.deleteMessage(messageId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<ChatMessage?> getMessage(String messageId) async {
    try {
      return await _repository.getMessage(messageId);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}
