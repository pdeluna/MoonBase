import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/models/chat_message.dart';
import 'package:moonbase_skeleton/models/enums.dart';
import 'package:moonbase_skeleton/providers/chat_provider.dart';
import 'package:moonbase_skeleton/providers/bases_provider.dart';
import 'package:moonbase_skeleton/services/session_controller.dart';
import 'package:moonbase_skeleton/utils/user_color_utils.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0, // Scroll to top (newest messages)
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _editMessage(ChatMessage message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final textController = TextEditingController(text: message.text);
        return AlertDialog(
          title: const Text('Edit Message'),
          content: TextField(
            controller: textController,
            decoration: const InputDecoration(
              hintText: 'Enter your message',
            ),
            maxLines: 3,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                // Pre-grab handlers
                final nav = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                final newText = textController.text.trim();
                
                if (newText.isNotEmpty && newText != message.text) {
                  try {
                    final chatActions = ref.read(chatActionsProvider.notifier);
                    await chatActions.editMessage(
                      messageId: message.id,
                      newText: newText,
                    );
                    
                    // Guard after async
                    if (!context.mounted) return;
                    
                    nav.pop();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Message edited successfully!')),
                    );
                  } catch (e) {
                    // Guard after async
                    if (!context.mounted) return;
                    
                    nav.pop();
                    messenger.showSnackBar(
                      SnackBar(content: Text('Failed to edit message: $e')),
                    );
                  }
                } else {
                  nav.pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _deleteMessage(ChatMessage message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Message'),
          content: const Text('Are you sure you want to delete this message? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                // Pre-grab handlers
                final nav = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                
                try {
                  final chatActions = ref.read(chatActionsProvider.notifier);
                  await chatActions.deleteMessage(message.id);
                  
                  // Guard after async
                  if (!context.mounted) return;
                  
                  nav.pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Message deleted successfully!')),
                  );
                } catch (e) {
                  // Guard after async
                  if (!context.mounted) return;
                  
                  nav.pop();
                  messenger.showSnackBar(
                    SnackBar(content: Text('Failed to delete message: $e')),
                  );
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }



  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      final chatActions = ref.read(chatActionsProvider.notifier);
      await chatActions.sendMessage(
        type: MessageType.text,
        text: text,
      );
      _messageController.clear();
             _scrollToTop();
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
    final session = ref.watch(sessionProvider);
    
    
    
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
            child: Consumer(
              builder: (context, ref, child) {
                final messagesAsync = ref.watch(chatMessagesProvider(selectedBase.id));
                
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
                     
                     // Sort messages by creation time (newest first for display)
                     final sortedMessages = List<ChatMessage>.from(messages)
                       ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                     
                     return ListView.builder(
                       controller: _scrollController,
                       reverse: true, // Show newest messages at the top
                       padding: const EdgeInsets.all(16),
                       itemCount: sortedMessages.length,
                       itemBuilder: (context, index) {
                         final message = sortedMessages[index];
                         final isMyMessage = session.value?.userId == message.authorUserId;
                         
                         return _MessageBubble(
                           message: message,
                           isMyMessage: isMyMessage,
                           onEditMessage: () => _editMessage(message),
                           onDeleteMessage: () => _deleteMessage(message),
                         );
                       },
                     );
                   },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(
                    child: Text('Error loading messages: $error'),
                  ),
                );
              },
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

class _MessageBubble extends ConsumerWidget {
  final ChatMessage message;
  final bool isMyMessage;
  final VoidCallback? onEditMessage;
  final VoidCallback? onDeleteMessage;

  const _MessageBubble({
    required this.message,
    required this.isMyMessage,
    this.onEditMessage,
    this.onDeleteMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (message.isDeleted) {
      return Align(
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Message deleted',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: isMyMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: isMyMessage ? () => _showMessageOptions(context) : null,
        child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isMyMessage 
            ? Theme.of(context).colorScheme.primary 
            : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMyMessage) ...[
                             Consumer(
                 builder: (context, ref, child) {
                   final profileAsync = ref.watch(profileByUserIdProvider(message.authorUserId));
                   final userColor = UserColorUtils.getColorForUserId(message.authorUserId);
                   
                                        return profileAsync.when(
                       data: (profile) => Text(
                         profile?.nickname ?? 'Unknown User',
                         style: TextStyle(
                           fontSize: 12,
                           fontWeight: FontWeight.bold,
                           color: userColor,
                         ),
                       ),
                       loading: () => Text(
                         'Loading...',
                         style: TextStyle(
                           fontSize: 12,
                           fontWeight: FontWeight.bold,
                           color: userColor.withValues(alpha: 0.6),
                         ),
                       ),
                       error: (_, __) => Text(
                         'Unknown User',
                         style: TextStyle(
                           fontSize: 12,
                           fontWeight: FontWeight.bold,
                           color: userColor.withValues(alpha: 0.6),
                         ),
                       ),
                     );
                 },
               ),
              const SizedBox(height: 2),
            ],
            if (message.text != null) ...[
              Text(
                message.text!,
                style: TextStyle(
                  color: isMyMessage 
                    ? Theme.of(context).colorScheme.onPrimary 
                    : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMyMessage 
                      ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7)
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                if (message.isEdited) ...[
                  const SizedBox(width: 4),
                  Text(
                    '(edited)',
                    style: TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: isMyMessage 
                        ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7)
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  void _showMessageOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Message'),
                onTap: () {
                  Navigator.pop(context);
                  onEditMessage?.call();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Message', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  onDeleteMessage?.call();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(time.year, time.month, time.day);
    
    if (messageDate == today) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController messageController;
  final VoidCallback onSendMessage;

  const _Composer({
    required this.messageController,
    required this.onSendMessage,
  });

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
