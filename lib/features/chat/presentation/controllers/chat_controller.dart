import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/chat_feed.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';
import 'package:moonbase_skeleton/features/chat/domain/usecases/send_message.dart';
import 'package:moonbase_skeleton/features/chat/domain/usecases/stream_messages.dart';
import 'package:moonbase_skeleton/features/chat/presentation/providers/chat_providers.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';

class ChatState {
  const ChatState({this.feed = const AsyncValue<ChatFeed>.loading()});

  final AsyncValue<ChatFeed> feed;

  ChatState copyWith({AsyncValue<ChatFeed>? feed}) =>
      ChatState(feed: feed ?? this.feed);
}

class ChatController extends StateNotifier<ChatState> {
  ChatController(this._sendMessage, this._streamMessages)
      : super(const ChatState());

  final SendMessage _sendMessage;
  final StreamMessages _streamMessages;

  StreamSubscription<ChatFeed>? _sub;

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

  /// Subscribe to the message stream. First paint is the first ChatFeed
  /// emission — do not mint a freshness value from listMessages.
  /// Pagination is not wired; listMessagesUseCaseProvider stays for that.
  Future<void> load(String baseId) async {
    _sub?.cancel();
    state = state.copyWith(feed: const AsyncValue<ChatFeed>.loading());

    developer.log('ChatController: Starting stream for base $baseId');
    _sub = _streamMessages(baseId.bid).listen(
      (feed) {
        developer.log(
          'ChatController: Received ${feed.messages.length} messages from stream',
        );
        state = state.copyWith(
          feed: AsyncValue.data(
            ChatFeed(
              messages: _newestFirst(feed.messages),
              freshness: feed.freshness,
            ),
          ),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        state = state.copyWith(feed: AsyncValue.error(error, stackTrace));
      },
    );
  }

  Future<void> send(
    String baseId,
    String userId,
    String content, {
    List<MediaRef> media = const [],
  }) async {
    developer.log(
      'ChatController: Sending message to base $baseId '
      '(media=${media.length})',
    );
    final res = await _sendMessage(SendMessageParams(
      baseId: baseId.bid,
      userId: userId.uid,
      content: content,
      media: media,
    ));
    res.match(
      (failure) {
        developer.log('ChatController: Send failed - ${failure.message}');
        throw Exception(failure.message);
      },
      (message) {
        developer.log(
          'ChatController: Message sent successfully - ${message.id.value}',
        );
        // Stream will automatically update the UI.
      },
    );
  }
}

final chatControllerProvider =
    StateNotifierProvider<ChatController, ChatState>((ref) {
  return ChatController(
    ref.read(sendMessageUseCaseProvider),
    ref.read(streamMessagesUseCaseProvider),
  );
});
