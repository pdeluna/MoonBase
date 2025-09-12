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

// Simplified chat messages provider - manages messages for a specific base
final chatMessagesProvider = StateNotifierProvider.family<ChatMessagesNotifier, AsyncValue<List<ChatMessage>>, String>((ref, baseId) {
  final repository = ref.watch(chatRepositoryProvider);
  final session = ref.watch(sessionProvider);
  return ChatMessagesNotifier(repository, session, baseId);
});

// Simplified chat actions provider - manages sending messages
final chatActionsProvider = StateNotifierProvider<ChatActionsNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(chatRepositoryProvider);
  final session = ref.watch(sessionProvider);
  final selectedBase = ref.watch(effectiveSelectedBaseProvider);
  
  return ChatActionsNotifier(repository, session, selectedBase);
});

class ChatMessagesNotifier extends StateNotifier<AsyncValue<List<ChatMessage>>> {
  ChatMessagesNotifier(this._repository, this._session, this._baseId) 
    : super(const AsyncValue.loading()) {
    // Use a microtask to ensure the constructor completes before async operations
    Future.microtask(() => _loadMessages());
  }

  final ChatRepository _repository;
  final AsyncValue<dynamic> _session;
  final String _baseId;

  Future<void> _loadMessages() async {
    if (_session.value == null) {
      state = const AsyncValue.data([]);
      return;
    }

    try {
      final messages = await _repository.getMessages(baseId: _baseId, limit: 50);
      state = AsyncValue.data(messages);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await _loadMessages();
  }

  // Add new message to the list
  void addMessage(ChatMessage message) {
    if (state.hasValue) {
      final currentMessages = state.value ?? [];
      final updatedMessages = [message, ...currentMessages];
      state = AsyncValue.data(updatedMessages);
    }
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
  }) async {
    if (_session.value == null) {
      throw Exception('User not authenticated');
    }

    if (_selectedBase == null) {
      throw Exception('No base selected');
    }

    try {
      state = const AsyncValue.loading();
      
      // Make API call
      final message = await _repository.sendMessage(
        baseId: _selectedBase.id,
        authorUserId: _session.value!.userId as String,
        type: type,
        text: text,
      );
      
      state = const AsyncValue.data(null);
      return message;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}
