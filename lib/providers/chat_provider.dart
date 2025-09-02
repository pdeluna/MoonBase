import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/models/chat_message.dart';
import 'package:moonbase_skeleton/models/media_ref.dart';
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

// Chat pagination provider - manages pagination state for a specific base
final chatPaginationProvider = StateNotifierProvider.family<ChatPaginationNotifier, ChatPaginationState, String>((ref, baseId) {
  return ChatPaginationNotifier();
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
      final messages = await _repository.getMessages(baseId: _baseId, limit: 50);
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
        limit: 50,
      );
      
      if (olderMessages.isEmpty) {
        // No more messages to load
        return;
      }
      
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

  // Add optimistic message immediately to UI
  void addOptimisticMessage(ChatMessage message) {
    if (state.hasValue) {
      final currentMessages = state.value ?? [];
      final updatedMessages = [message, ...currentMessages];
      state = AsyncValue.data(updatedMessages);
    }
  }

  // Replace optimistic message with real message
  void replaceOptimisticMessage(String tempId, ChatMessage realMessage) {
    if (state.hasValue) {
      final currentMessages = state.value ?? [];
      final updatedMessages = currentMessages.map((msg) {
        if (msg.id == tempId) {
          return realMessage;
        }
        return msg;
      }).toList();
      state = AsyncValue.data(updatedMessages);
    }
  }

  // Remove optimistic message (on error)
  void removeOptimisticMessage(String tempId) {
    if (state.hasValue) {
      final currentMessages = state.value ?? [];
      final updatedMessages = currentMessages.where((msg) => msg.id != tempId).toList();
      state = AsyncValue.data(updatedMessages);
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }
}

// New pagination state class
class ChatPaginationState {
  final bool isLoadingMore;
  final bool hasMoreMessages;
  final String? lastMessageId;
  final String? error;

  const ChatPaginationState({
    this.isLoadingMore = false,
    this.hasMoreMessages = true,
    this.lastMessageId,
    this.error,
  });

  ChatPaginationState copyWith({
    bool? isLoadingMore,
    bool? hasMoreMessages,
    String? lastMessageId,
    String? error,
  }) {
    return ChatPaginationState(
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMoreMessages: hasMoreMessages ?? this.hasMoreMessages,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      error: error ?? this.error,
    );
  }
}

// New pagination notifier
class ChatPaginationNotifier extends StateNotifier<ChatPaginationState> {
  ChatPaginationNotifier() : super(const ChatPaginationState());

  void setLoadingMore(bool loading) {
    state = state.copyWith(isLoadingMore: loading);
  }

  void setHasMoreMessages(bool hasMore) {
    state = state.copyWith(hasMoreMessages: hasMore);
  }

  void setLastMessageId(String? messageId) {
    state = state.copyWith(lastMessageId: messageId);
  }

  void setError(String? error) {
    state = state.copyWith(error: error);
  }

  void reset() {
    state = const ChatPaginationState();
  }
}

class ChatActionsNotifier extends StateNotifier<AsyncValue<void>> {
  ChatActionsNotifier(this._repository, this._session, this._selectedBase) 
    : super(const AsyncValue.data(null));

  final ChatRepository _repository;
  final AsyncValue<dynamic> _session;
  final Base? _selectedBase;
  
  // Callback for optimistic updates
  Function(ChatMessage)? onOptimisticMessage;
  Function(String, ChatMessage)? onReplaceOptimisticMessage;
  Function(String)? onRemoveOptimisticMessage;

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

    // Create optimistic message
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticMessage = ChatMessage(
      id: tempId,
      baseId: _selectedBase.id,
      authorUserId: _session.value!.userId,
      type: type,
      text: text,
      media: mediaUrls?.map((url) => MediaRef(
        id: 'temp_media_${DateTime.now().millisecondsSinceEpoch}',
        uri: url,
        type: MediaType.image,
      )).toList(),
      createdAt: DateTime.now(),
      replyToMessageId: replyToMessageId,
    );

    try {
      // Add optimistic message to UI immediately
      onOptimisticMessage?.call(optimisticMessage);
      
      state = const AsyncValue.loading();
      
      // Make API call
      final realMessage = await _repository.sendMessage(
        baseId: _selectedBase.id,
        authorUserId: _session.value!.userId,
        type: type,
        text: text,
        mediaUrls: mediaUrls,
        replyToMessageId: replyToMessageId,
      );
      
      // Replace optimistic message with real message
      onReplaceOptimisticMessage?.call(tempId, realMessage);
      
      state = const AsyncValue.data(null);
      return realMessage;
    } catch (e, st) {
      // Remove optimistic message on error
      onRemoveOptimisticMessage?.call(tempId);
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
      // Create optimistic edited message
      final optimisticMessage = ChatMessage(
        id: messageId,
        baseId: _selectedBase?.id ?? '',
        authorUserId: _session.value!.userId,
        type: MessageType.text,
        text: newText,
        createdAt: DateTime.now(),
        isEdited: true,
        editedAt: DateTime.now(),
      );

      // Add optimistic update to UI immediately
      onOptimisticMessage?.call(optimisticMessage);
      
      state = const AsyncValue.loading();
      final message = await _repository.editMessage(
        messageId: messageId,
        newText: newText,
      );
      
      // Replace optimistic message with real message
      onReplaceOptimisticMessage?.call(messageId, message);
      
      state = const AsyncValue.data(null);
      return message;
    } catch (e, st) {
      // Remove optimistic update on error
      onRemoveOptimisticMessage?.call(messageId);
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteMessage(String messageId) async {
    if (_session.value == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Create optimistic deleted message
      final optimisticMessage = ChatMessage(
        id: messageId,
        baseId: _selectedBase?.id ?? '',
        authorUserId: _session.value!.userId,
        type: MessageType.text,
        text: null,
        createdAt: DateTime.now(),
        isDeleted: true,
      );

      // Add optimistic update to UI immediately
      onOptimisticMessage?.call(optimisticMessage);
      
      state = const AsyncValue.loading();
      await _repository.deleteMessage(messageId);
      
      // Optimistic update is already in place, no need to replace
      state = const AsyncValue.data(null);
    } catch (e, st) {
      // Remove optimistic update on error
      onRemoveOptimisticMessage?.call(messageId);
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
