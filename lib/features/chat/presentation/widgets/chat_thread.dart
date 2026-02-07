import 'package:flutter/material.dart';
import 'package:moonbase_skeleton/features/chat/presentation/widgets/message_bubble.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';

class ChatThread extends StatelessWidget {
  const ChatThread({
    super.key, 
    required this.messages,
    required this.currentUserId,
  });
  
  final List<Message> messages;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
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

    return ListView.builder(
      reverse: true, // newest at bottom
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return MessageBubble(
          key: ValueKey(message.id.value),
          message: message,
          currentUserId: currentUserId,
        );
      },
    );
  }
}
