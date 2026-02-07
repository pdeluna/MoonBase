import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';
import 'package:moonbase_skeleton/features/chat/presentation/providers/chat_providers.dart';
import 'package:moonbase_skeleton/features/chat/domain/usecases/list_messages.dart';
import 'package:moonbase_skeleton/features/chat/domain/usecases/send_message.dart';
import 'package:moonbase_skeleton/features/chat/domain/usecases/stream_messages.dart';
import 'package:moonbase_skeleton/core/ids.dart';


class ChatState {
  const ChatState({this.messages = const AsyncValue.data([])});

  final AsyncValue<List<Message>> messages;

  ChatState copyWith({AsyncValue<List<Message>>? messages}) =>
      ChatState(messages: messages ?? this.messages);
}

class ChatController extends StateNotifier<ChatState> {
  ChatController(this._listMessages, this._sendMessage, this._streamMessages)
      : super(const ChatState());

  final ListMessages _listMessages;
  final SendMessage _sendMessage;
  final StreamMessages _streamMessages;

  StreamSubscription<List<Message>>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// Sorts messages newest first so ListView(reverse: true) shows newest at bottom.
  static List<Message> _newestFirst(List<Message> list) {
    final copy = List<Message>.from(list);
    copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return copy;
  }

  Future<void> load(String baseId) async {
    _sub?.cancel();
    state = state.copyWith(messages: const AsyncValue.loading());

    final res = await _listMessages(ListMessagesParams(baseId: baseId.bid));
    state = res.match(
      (f) => state.copyWith(messages: AsyncValue.error(f, StackTrace.current)),
      (list) => state.copyWith(messages: AsyncValue.data(_newestFirst(list))),
    );

    developer.log('ChatController: Starting stream for base $baseId');
    _sub = _streamMessages(baseId.bid).listen((list) {
      developer.log('ChatController: Received ${list.length} messages from stream');
      state = state.copyWith(messages: AsyncValue.data(_newestFirst(list)));
    });
  }

  Future<void> send(String baseId, String userId, String content) async {
    developer.log('ChatController: Sending message to base $baseId');
    final res = await _sendMessage(SendMessageParams(baseId: baseId.bid, userId: userId.uid, content: content));
    res.match(
      (failure) {
        developer.log('ChatController: Send failed - ${failure.message}');
        throw Exception(failure.message);
      },
      (message) {
        developer.log('ChatController: Message sent successfully - ${message.id.value}');
        // Stream will automatically update the UI
      },
    );
  }
}

final chatControllerProvider = StateNotifierProvider<ChatController, ChatState>((ref) {
  return ChatController(
    ref.read(listMessagesUseCaseProvider),
    ref.read(sendMessageUseCaseProvider),
    ref.read(streamMessagesUseCaseProvider),
  );
});
