import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/core/presentation/debug_error_details.dart';
import 'package:moonbase_skeleton/core/presentation/failure_presenter.dart';
import 'package:moonbase_skeleton/core/presentation/failure_snackbar.dart';
import 'package:moonbase_skeleton/core/sync_status.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/chat_feed.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';
import 'package:moonbase_skeleton/features/chat/presentation/providers/chat_screen_vm_provider.dart';
import 'package:moonbase_skeleton/features/chat/presentation/controllers/chat_controller.dart';
import 'package:moonbase_skeleton/features/chat/presentation/widgets/cached_messages_banner.dart';
import 'package:moonbase_skeleton/features/chat/presentation/widgets/message_composer.dart';
import 'package:moonbase_skeleton/features/chat/presentation/widgets/message_bubble.dart';
import 'package:moonbase_skeleton/core/validators.dart';
import 'package:moonbase_skeleton/features/auth/domain/entities/user.dart';
import 'package:moonbase_skeleton/features/auth/presentation/providers/member_presentation_provider.dart';
import 'package:moonbase_skeleton/features/bases/presentation/providers/sidebar_providers.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/presentation/providers/media_providers.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_group.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_target.dart';
import 'package:moonbase_skeleton/features/reactions/presentation/controllers/reaction_controller.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  String? _loadedBaseId;

  /// Parent-owned list of staged attachments; the dumb composer renders it
  /// and emits stage / unstage intents we route through here. Handed to the
  /// pending message on send (the outbox entry owns the staged keys from
  /// then on) and cleared immediately, along with the text.
  List<MediaRef> _stagedMedia = const <MediaRef>[];

  /// Gates the one-shot basesList refresh on screen entry (not every rebuild).
  bool _didRefreshBasesOnEntry = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _stageMedia(MediaRef ref) {
    setState(() {
      _stagedMedia = [..._stagedMedia, ref];
    });
  }

  Future<void> _unstageMedia(MediaRef m) async {
    setState(() {
      _stagedMedia = _stagedMedia.where((s) => s.id != m.id).toList();
    });
    // Clean up the bytes we wrote when the user picked this media. The
    // bytes were persisted by PickAndPersistMedia; an explicit × is a
    // "throw it away" signal, not a "keep an orphan" one.
    final deleteMedia = ref.read(deleteMediaUseCaseProvider);
    final result = await deleteMedia(m.storageKey);
    result.match(
      (failure) {
        // Best-effort delete failure is non-fatal — the file may be GC'd
        // by a future sweep. Plain copy on the snackbar; raw detail stays
        // on the debug long-press.
        if (mounted) {
          showFailureSnackBar(
            context,
            failure,
            prefix: "Couldn't remove that attachment",
          );
        }
      },
      (_) {},
    );
  }

  /// Clear-on-send (bug B-c): the composer empties the instant the user taps
  /// send; the message shows up as a pending bubble and every outcome
  /// (success, failure, retry) is reported through `ChatState`, never
  /// thrown back here.
  void _sendMessage() {
    final text = _messageController.text.trim();
    if (!isValidMessageInput(text: text, mediaCount: _stagedMedia.length)) {
      _showErrorSnackBar(
        text.length > kMessageMaxLen
            ? 'That message is too long.'
            : 'Write something or add a photo.',
      );
      return;
    }

    final vm = ref.read(chatScreenVmProvider);
    if (!vm.canSendMessage) {
      _showErrorSnackBar('Sign in and pick a base first.');
      return;
    }

    final mediaToSend = _stagedMedia;
    _messageController.clear();
    setState(() {
      _stagedMedia = const <MediaRef>[];
    });

    unawaited(
      ref.read(chatControllerProvider.notifier).send(
            vm.selectedBase!.id.value,
            vm.currentUser!.id.value,
            text,
            media: mediaToSend,
          ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  /// Failure alert for a pending send. Presenter copy (no `Exception:`
  /// prefix) with a Retry action; the bubble itself stays tappable for
  /// the same retry.
  void _showSendFailure(SendFailureEvent event) {
    if (!mounted) return;
    showFailureSnackBar(
      context,
      event.failure,
      prefix: 'Message not sent',
      onRetry: () => ref
          .read(chatControllerProvider.notifier)
          .retry(event.messageId.value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(chatScreenVmProvider);

    final currentUserId = vm.currentUser?.id.value;

    void loadBase(String baseId) {
      ref
          .read(chatControllerProvider.notifier)
          .load(baseId, userId: currentUserId);
      ref.read(reactionControllerProvider.notifier).load(baseId);
    }

    // ref.listen must be called from build; handles base changes
    ref.listen<Base?>(effectiveSelectedBaseProvider, (previous, next) {
      if (next != null) {
        _loadedBaseId = next.id.value;
        loadBase(next.id.value);
      }
    });

    ref.listen<SendFailureEvent?>(
      chatControllerProvider.select((s) => s.lastSendFailure),
      (previous, next) {
        if (next != null && next != previous) _showSendFailure(next);
      },
    );

    ref.listen<ReactionFailureEvent?>(
      reactionControllerProvider.select((s) => s.lastFailure),
      (previous, next) {
        if (next != null && next != previous) {
          showFailureSnackBar(
            context,
            next.failure,
            prefix: 'Couldn\'t update reaction',
          );
        }
      },
    );

    // Initial load when opening chat with a base already selected (only once per base)
    if (vm.hasSelectedBase) {
      final baseId = vm.selectedBase!.id.value;
      if (_loadedBaseId != baseId) {
        _loadedBaseId = baseId;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _loadedBaseId == baseId) loadBase(baseId);
        });
      }
    } else {
      _loadedBaseId = null;
    }

    // One-shot on screen entry only — do NOT invalidate every rebuild
    // (that caused an infinite basesList refetch / log-flood loop).
    if (!_didRefreshBasesOnEntry) {
      _didRefreshBasesOnEntry = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.invalidate(basesListProvider);
      });
    }

    if (!vm.hasSelectedBase) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Chat'),
          backgroundColor: Theme.of(context).colorScheme.surface,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 64,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                'Please select a base to start chatting',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final chatState = ref.watch(chatControllerProvider);
    final baseId = vm.selectedBase!.id.value;

    return Scaffold(
      appBar: AppBar(
        title: Text('Chat - ${vm.selectedBase!.name}'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: Column(
        children: [
          CachedMessagesBanner(
            freshness: vm.freshness,
            hasMessages: vm.hasMessages,
          ),
          Expanded(
            child: _ChatBody(
              feedAsync: chatState.feed,
              messages: vm.messages,
              reactionsByMessage: vm.reactionsByMessage,
              baseId: baseId,
              currentUser: vm.currentUser,
            ),
          ),
          MessageComposer(
            messageController: _messageController,
            onSendMessage: _sendMessage,
            canSend: vm.canSendMessage,
            baseId: vm.selectedBase!.id,
            stagedMedia: _stagedMedia,
            onStage: _stageMedia,
            onUnstage: _unstageMedia,
          ),
        ],
      ),
    );
  }
}

/// Single place for chat content: loading / error+retry / empty / message list.
/// Uses AsyncValue.when at screen level. [messages] is the VM's merged
/// (feed ∪ pending, deduped) list — rendered instead of the raw feed so
/// pending bubbles appear inline.
class _ChatBody extends ConsumerWidget {
  const _ChatBody({
    required this.feedAsync,
    required this.messages,
    required this.reactionsByMessage,
    required this.baseId,
    required this.currentUser,
  });

  final AsyncValue<ChatFeed> feedAsync;
  final List<Message> messages;
  final Map<String, ReactionGroup> reactionsByMessage;
  final String baseId;
  final User? currentUser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return feedAsync.when(
      loading: () => const _ChatStateContent(
        kind: _ChatStateKind.loading,
      ),
      error: (Object error, StackTrace stackTrace) => _ChatStateContent(
        kind: _ChatStateKind.error,
        error: error,
        stackTrace: stackTrace,
        onRetry: () => ref.read(chatControllerProvider.notifier).load(
              baseId,
              userId: currentUser?.id.value,
            ),
      ),
      data: (ChatFeed feed) {
        if (messages.isEmpty) {
          return const _ChatStateContent(kind: _ChatStateKind.empty);
        }
        return _ChatMessageList(
          messages: messages,
          reactionsByMessage: reactionsByMessage,
          baseId: baseId,
          currentUserId: currentUser?.id.value,
        );
      },
    );
  }
}

enum _ChatStateKind { loading, error, empty }

class _ChatStateContent extends StatelessWidget {
  const _ChatStateContent({
    required this.kind,
    this.error,
    this.stackTrace,
    this.onRetry,
  });

  final _ChatStateKind kind;
  final Object? error;
  final StackTrace? stackTrace;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case _ChatStateKind.loading:
        return const Center(child: CircularProgressIndicator());
      case _ChatStateKind.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  "Couldn't load messages.",
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  DebugErrorDetails(
                    error: error,
                    stackTrace: stackTrace,
                    child: Text(
                      userMessage(error),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                if (onRetry != null) ...[
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: onRetry,
                    child: const Text('Retry'),
                  ),
                ],
              ],
            ),
          ),
        );
      case _ChatStateKind.empty:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 64,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                'No messages yet. Start the conversation!',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        );
    }
  }
}

/// Message list with scroll-to-latest when new messages appear.
class _ChatMessageList extends ConsumerStatefulWidget {
  const _ChatMessageList({
    required this.messages,
    required this.reactionsByMessage,
    required this.baseId,
    required this.currentUserId,
  });

  final List<Message> messages;
  final Map<String, ReactionGroup> reactionsByMessage;
  final String baseId;
  final String? currentUserId;

  @override
  ConsumerState<_ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends ConsumerState<_ChatMessageList> {
  final ScrollController _scrollController = ScrollController();
  int _previousMessageCount = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Scroll to bottom when new message appears (reverse: true => 0 is bottom)
    if (widget.messages.length > _previousMessageCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
      _previousMessageCount = widget.messages.length;
    } else if (widget.messages.length < _previousMessageCount) {
      _previousMessageCount = widget.messages.length;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView.builder(
        controller: _scrollController,
        reverse: true,
        itemCount: widget.messages.length,
        itemBuilder: (context, index) {
          final message = widget.messages[index];
          final member =
              ref.watch(memberPresentationProvider(message.userId.value));
          final isFailed = message.syncStatus == SyncStatus.failed;
          final me = widget.currentUserId;
          return MessageBubble(
            key: ValueKey(message.id.value),
            message: message,
            currentUserId: me,
            senderNickname: member.nickname,
            senderColor: member.nameColor,
            reactions: widget.reactionsByMessage[message.id.value],
            onReact: me == null || message.isPending
                ? null
                : (kind) =>
                    ref.read(reactionControllerProvider.notifier).toggle(
                          baseId: widget.baseId,
                          target: ReactionTarget(
                            kind: ReactionTargetKind.message,
                            id: message.id.value,
                          ),
                          userId: me,
                          kind: kind,
                        ),
            onRetry: isFailed
                ? () => ref
                    .read(chatControllerProvider.notifier)
                    .retry(message.id.value)
                : null,
            onDiscard: isFailed
                ? () => ref
                    .read(chatControllerProvider.notifier)
                    .discard(message.id.value)
                : null,
          );
        },
      ),
    );
  }
}
