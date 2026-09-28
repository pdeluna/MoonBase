import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/core/presentation/failure_presenter.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';
import 'package:moonbase_skeleton/features/chat/presentation/viewmodels/chat_screen_vm.dart';
import 'package:moonbase_skeleton/features/chat/presentation/controllers/chat_controller.dart';
import 'package:moonbase_skeleton/features/auth/presentation/providers/auth_providers.dart';
import 'package:moonbase_skeleton/features/bases/presentation/providers/sidebar_providers.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_group.dart';
import 'package:moonbase_skeleton/features/reactions/presentation/controllers/reaction_controller.dart';

/// Provider for chat screen view model
final chatScreenVmProvider = Provider<ChatScreenVM>((ref) {
  final selectedBase = ref.watch(effectiveSelectedBaseProvider);
  final currentUser = ref.watch(currentUserProvider).valueOrNull;
  final chatState = ref.watch(chatControllerProvider);

  // Log base selection for debugging
  developer.log(
      'ChatScreenVM: selectedBase = ${selectedBase?.name} (${selectedBase?.id})');
  developer.log(
      'ChatScreenVM: currentUser = ${currentUser?.nickname} (${currentUser?.id})');

  // selectedBase is already a Base entity from the new architecture
  final baseEntity = selectedBase;

  // canSendMessage should only depend on having a base and user, not chat state
  final canSend = baseEntity != null && currentUser != null;
  developer.log(
      'ChatScreenVM: canSend = $canSend (baseEntity: ${baseEntity != null}, currentUser: ${currentUser != null})');

  // Pending sends for this base only; the merge dedupes against the feed.
  final pendingForBase = baseEntity == null
      ? const <Message>[]
      : chatState.pending
          .map((p) => p.message)
          .where((m) => m.baseId == baseEntity.id);

  // Reactions: one listener per screen, joined here by message id. A
  // loading/errored reactions feed (e.g. index not yet Enabled) yields no
  // chips — the chat still renders.
  final reactionState = ref.watch(reactionControllerProvider);
  Map<String, ReactionGroup> joinReactions(List<Message> messages) {
    final me = currentUser?.id;
    final out = <String, ReactionGroup>{};
    for (final m in messages) {
      if (m.isPending) continue;
      final g = reactionState.groupFor(m.id.value, me);
      if (!g.isEmpty) out[m.id.value] = g;
    }
    return Map.unmodifiable(out);
  }

  return chatState.feed.when(
    data: (feed) {
      final messages = ChatScreenVM.mergePending(feed.messages, pendingForBase);
      return ChatScreenVM(
        selectedBase: baseEntity,
        currentUser: currentUser,
        messages: messages,
        isLoading: false,
        error: null,
        canSendMessage: canSend,
        freshness: feed.freshness,
        reactionsByMessage: joinReactions(messages),
      );
    },
    loading: () => ChatScreenVM(
      selectedBase: baseEntity,
      currentUser: currentUser,
      messages: const [],
      isLoading: true,
      error: null,
      canSendMessage: canSend,
    ),
    error: (error, _) => ChatScreenVM(
      selectedBase: baseEntity,
      currentUser: currentUser,
      messages: const [],
      isLoading: false,
      error: userMessage(error),
      canSendMessage: canSend,
    ),
  );
});
