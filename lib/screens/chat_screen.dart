import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/models/enums.dart';
import 'package:moonbase_skeleton/providers/chat_provider.dart';
import 'package:moonbase_skeleton/providers/bases_provider.dart';
import 'package:moonbase_skeleton/features/auth/presentation/providers/auth_providers.dart';
import 'package:moonbase_skeleton/features/auth/domain/entities/user.dart';
import 'package:moonbase_skeleton/features/chat/presentation/widgets/chat_thread.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      final selectedBase = ref.read(effectiveSelectedBaseProvider);
      if (selectedBase == null) return;

      final chatActions = ref.read(chatActionsProvider.notifier);
      final chatMessagesNotifier = ref.read(chatMessagesProvider(selectedBase.id).notifier);
      
      // Send the message
      final message = await chatActions.sendMessage(
        type: MessageType.text,
        text: text,
      );
      
      // Add the message to the local state
      chatMessagesNotifier.addMessage(message);
      
      _messageController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedBase = ref.watch(effectiveSelectedBaseProvider);
    final user = ref.watch(currentUserProvider);
    
    if (selectedBase == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please select a base to start chatting'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Chat - ${selectedBase.name}'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: Column(
        children: [
          Expanded(
            child: _ChatMessagesList(
              baseId: selectedBase.id,
              user: user,
            ),
          ),
          _Composer(
            messageController: _messageController,
            onSendMessage: _sendMessage,
          ),
        ],
      ),
    );
  }
}

class _ChatMessagesList extends ConsumerWidget {
  const _ChatMessagesList({
    required this.baseId,
    required this.user,
  });
  
  final String baseId;
  final User? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(chatMessagesProvider(baseId));
    
    return messagesAsync.when(
      data: (messages) {
        if (messages.isEmpty) {
          return const Center(
            child: Text(
              'No messages yet. Start the conversation!',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          );
        }
        
        return Padding(
          padding: const EdgeInsets.all(16),
          child: ChatThread(baseId: baseId),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Error loading messages: $error'),
      ),
    );
  }
}


class _Composer extends StatelessWidget {
  const _Composer({
    required this.messageController,
    required this.onSendMessage,
  });
  
  final TextEditingController messageController;
  final VoidCallback onSendMessage;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: messageController,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                onSubmitted: (_) => onSendMessage(),
                textCapitalization: TextCapitalization.sentences,
                maxLines: null,
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              onPressed: onSendMessage,
              child: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
