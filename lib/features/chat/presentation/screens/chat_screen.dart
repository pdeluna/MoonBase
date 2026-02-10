import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';
import 'package:moonbase_skeleton/features/chat/presentation/providers/chat_screen_vm_provider.dart';
import 'package:moonbase_skeleton/features/chat/presentation/controllers/chat_controller.dart';
import 'package:moonbase_skeleton/features/chat/presentation/widgets/message_composer.dart';
import 'package:moonbase_skeleton/features/chat/presentation/widgets/message_bubble.dart';
import 'package:moonbase_skeleton/core/validators.dart';
import 'package:moonbase_skeleton/features/auth/domain/entities/user.dart';
import 'package:moonbase_skeleton/features/auth/presentation/providers/member_presentation_provider.dart';
import 'package:moonbase_skeleton/features/bases/presentation/providers/sidebar_providers.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  String? _loadedBaseId;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (!isValidMessage(text)) {
      _showErrorSnackBar('Message must be between 1 and 1000 characters');
      return;
    }

    final vm = ref.read(chatScreenVmProvider);
    if (!vm.canSendMessage) {
      _showErrorSnackBar('Cannot send message: no base selected or user not authenticated');
      return;
    }

    try {
      final chatController = ref.read(chatControllerProvider.notifier);
      await chatController.send(
        vm.selectedBase!.id.value,
        vm.currentUser!.id.value,
        text,
      );

      _messageController.clear();
    } catch (e) {
      _showErrorSnackBar('Failed to send message: $e');
    }
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

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(chatScreenVmProvider);

    // ref.listen must be called from build; handles base changes
    ref.listen<Base?>(effectiveSelectedBaseProvider, (previous, next) {
      if (next != null) {
        _loadedBaseId = next.id.value;
        ref.read(chatControllerProvider.notifier).load(next.id.value);
      }
    });

    // Initial load when opening chat with a base already selected (only once per base)
    if (vm.hasSelectedBase) {
      final baseId = vm.selectedBase!.id.value;
      if (_loadedBaseId != baseId) {
        _loadedBaseId = baseId;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _loadedBaseId == baseId) {
            ref.read(chatControllerProvider.notifier).load(baseId);
          }
        });
      }
    } else {
      _loadedBaseId = null;
    }

    // Force refresh bases list when chat screen loads to ensure we have latest data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(basesListProvider);
    });

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
          Expanded(
            child: _ChatBody(
              messagesAsync: chatState.messages,
              baseId: baseId,
              currentUser: vm.currentUser,
            ),
          ),
          MessageComposer(
            messageController: _messageController,
            onSendMessage: _sendMessage,
            canSend: vm.canSendMessage,
          ),
        ],
      ),
    );
  }
}

/// Single place for chat content: loading / error+retry / empty / message list.
/// Uses AsyncValue.when at screen level.
class _ChatBody extends ConsumerWidget {
  const _ChatBody({
    required this.messagesAsync,
    required this.baseId,
    required this.currentUser,
  });

  final AsyncValue<List<Message>> messagesAsync;
  final String baseId;
  final User? currentUser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return messagesAsync.when(
      loading: () => const _ChatStateContent(
        kind: _ChatStateKind.loading,
      ),
      error: (Object error, StackTrace _) => _ChatStateContent(
        kind: _ChatStateKind.error,
        errorMessage: error.toString(),
        onRetry: () => ref.read(chatControllerProvider.notifier).load(baseId),
      ),
      data: (List<Message> messages) {
        if (messages.isEmpty) {
          return const _ChatStateContent(kind: _ChatStateKind.empty);
        }
        return _ChatMessageList(
          messages: messages,
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
    this.errorMessage,
    this.onRetry,
  });

  final _ChatStateKind kind;
  final String? errorMessage;
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
                  'Error loading messages',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorMessage!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                    textAlign: TextAlign.center,
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
    required this.currentUserId,
  });

  final List<Message> messages;
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
          final member = ref.watch(memberPresentationProvider(message.userId.value));
          return MessageBubble(
            key: ValueKey(message.id.value),
            message: message,
            currentUserId: widget.currentUserId,
            senderNickname: member.nickname,
            senderColor: member.nameColor,
          );
        },
      ),
    );
  }
}
