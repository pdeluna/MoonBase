import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/features/chat/presentation/viewmodels/chat_screen_vm.dart';
import 'package:moonbase_skeleton/features/chat/presentation/providers/chat_screen_vm_provider.dart';
import 'package:moonbase_skeleton/features/chat/presentation/controllers/chat_controller.dart';
import 'package:moonbase_skeleton/features/chat/presentation/widgets/message_composer.dart';
import 'package:moonbase_skeleton/features/chat/presentation/widgets/message_bubble.dart';
import 'package:moonbase_skeleton/core/validators.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Text('Chat - ${vm.selectedBase!.name}'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: Column(
        children: [
          Expanded(
            child: _ChatMessagesList(
              baseId: vm.selectedBase!.id.value,
              vm: vm,
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

class _ChatMessagesList extends ConsumerWidget {
  const _ChatMessagesList({
    required this.baseId,
    required this.vm,
  });
  
  final String baseId;
  final ChatScreenVM vm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (vm.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.hasError) {
      return Center(
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
            ),
            const SizedBox(height: 8),
            Text(
              vm.error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final chatController = ref.read(chatControllerProvider.notifier);
                chatController.load(baseId);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (!vm.hasMessages) {
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
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _ChatMessagesFromController(vm: vm),
    );
  }
}

class _ChatMessagesFromController extends ConsumerWidget {
  const _ChatMessagesFromController({required this.vm});
  
  final ChatScreenVM vm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (vm.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.hasError) {
      return Center(
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
            ),
            const SizedBox(height: 8),
            Text(
              vm.error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final chatController = ref.read(chatControllerProvider.notifier);
                chatController.load(vm.selectedBase!.id.value);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (!vm.hasMessages) {
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

    return ListView.builder(
      reverse: true, // newest at bottom
      itemCount: vm.messages.length,
      itemBuilder: (context, index) {
        final message = vm.messages[index];
        final member = ref.watch(memberPresentationProvider(message.userId.value));
        return MessageBubble(
          key: ValueKey(message.id.value),
          message: message,
          currentUserId: vm.currentUser?.id.value,
          senderNickname: member.nickname,
          senderColor: member.nameColor,
        );
      },
    );
  }
}
