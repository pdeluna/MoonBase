import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/message.dart';
import '../providers/chat_providers.dart';
import '../../domain/usecases/list_messages.dart';
import '../../domain/usecases/send_message.dart';
import '../../domain/usecases/stream_messages.dart';


class ChatState {
  final AsyncValue<List<Message>> messages;
  const ChatState({this.messages = const AsyncValue.data(const [])});

  ChatState copyWith({AsyncValue<List<Message>>? messages}) =>
      ChatState(messages: messages ?? this.messages);
}

class ChatController extends StateNotifier<ChatState> {
  final ListMessages _listMessages;
  final SendMessage _sendMessage;
  final StreamMessages _streamMessages;

  StreamSubscription<List<Message>>? _sub;

  ChatController(this._listMessages, this._sendMessage, this._streamMessages)
      : super(const ChatState());

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> load(String baseId) async {
    state = state.copyWith(messages: const AsyncValue.loading());
    final res = await _listMessages(ListMessagesParams(baseId: baseId));
    state = res.match(
      (f) => state.copyWith(messages: AsyncValue.error(f, StackTrace.current)),
      (list) => state.copyWith(messages: AsyncValue.data(list)),
    );
  }

  void subscribe(String baseId) {
    _sub?.cancel();
    _sub = _streamMessages(baseId).listen((list) {
      state = state.copyWith(messages: AsyncValue.data(list));
    });
  }

  Future<void> send(String baseId, String userId, String content) async {
    final res = await _sendMessage(SendMessageParams(baseId: baseId, userId: userId, content: content));
    res.match(
      (_) => {}, // on failure, keep existing state (UI can surface errors if you propagate)
      (_) => {}, // stream will push the new list
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
