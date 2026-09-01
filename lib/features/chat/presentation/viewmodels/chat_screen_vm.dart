import 'package:moonbase_skeleton/features/chat/domain/entities/chat_freshness.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/auth/domain/entities/user.dart';

class ChatScreenVM {
  const ChatScreenVM({
    required this.selectedBase,
    required this.currentUser,
    required this.messages,
    required this.isLoading,
    required this.error,
    required this.canSendMessage,
    this.freshness,
  });

  final Base? selectedBase;
  final User? currentUser;
  final List<Message> messages;
  final bool isLoading;
  final String? error;
  final bool canSendMessage;

  /// Null until the message stream has emitted a ChatFeed.
  final ChatFreshness? freshness;

  bool get hasSelectedBase => selectedBase != null;
  bool get hasMessages => messages.isNotEmpty;
  bool get hasError => error != null;

  ChatScreenVM copyWith({
    Base? selectedBase,
    User? currentUser,
    List<Message>? messages,
    bool? isLoading,
    String? error,
    bool? canSendMessage,
    ChatFreshness? freshness,
  }) {
    return ChatScreenVM(
      selectedBase: selectedBase ?? this.selectedBase,
      currentUser: currentUser ?? this.currentUser,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      canSendMessage: canSendMessage ?? this.canSendMessage,
      freshness: freshness ?? this.freshness,
    );
  }
}
