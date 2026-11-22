import 'package:moonbase_skeleton/features/chat/domain/entities/chat_freshness.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/auth/domain/entities/user.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_group.dart';

class ChatScreenVM {
  const ChatScreenVM({
    required this.selectedBase,
    required this.currentUser,
    required this.messages,
    required this.isLoading,
    required this.error,
    required this.canSendMessage,
    this.freshness,
    this.reactionsByMessage = const <String, ReactionGroup>{},
  });

  final Base? selectedBase;
  final User? currentUser;

  /// Newest first. Live feed messages plus this device's pending sends for
  /// the selected base (deduped by id — a pending entry whose document has
  /// already arrived in the feed is not shown twice). Pending entries carry
  /// `Message.syncStatus` `uploading` / `failed` for the bubble to render.
  final List<Message> messages;
  final bool isLoading;
  final String? error;
  final bool canSendMessage;

  /// Null until the message stream has emitted a ChatFeed.
  final ChatFreshness? freshness;

  /// Message id → chip-row model, joined client-side from the single
  /// reactions listener (only ids present in [messages]; empty groups
  /// omitted). Derived every build — never stored on the message.
  final Map<String, ReactionGroup> reactionsByMessage;

  bool get hasSelectedBase => selectedBase != null;
  bool get hasMessages => messages.isNotEmpty;
  bool get hasError => error != null;

  /// Merge helper shared by the provider and tests: feed messages win over a
  /// pending copy with the same id; result is newest first.
  static List<Message> mergePending(
    List<Message> feed,
    Iterable<Message> pending,
  ) {
    final ids = feed.map((m) => m.id).toSet();
    final merged = <Message>[
      ...feed,
      ...pending.where((p) => !ids.contains(p.id)),
    ];
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List<Message>.unmodifiable(merged);
  }

  ChatScreenVM copyWith({
    Base? selectedBase,
    User? currentUser,
    List<Message>? messages,
    bool? isLoading,
    String? error,
    bool? canSendMessage,
    ChatFreshness? freshness,
    Map<String, ReactionGroup>? reactionsByMessage,
  }) {
    return ChatScreenVM(
      selectedBase: selectedBase ?? this.selectedBase,
      currentUser: currentUser ?? this.currentUser,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      canSendMessage: canSendMessage ?? this.canSendMessage,
      freshness: freshness ?? this.freshness,
      reactionsByMessage: reactionsByMessage ?? this.reactionsByMessage,
    );
  }
}
