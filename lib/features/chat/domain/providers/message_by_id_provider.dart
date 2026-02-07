import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';
import 'package:moonbase_skeleton/features/chat/presentation/providers/chat_providers.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/providers/bases_provider.dart';

/// Provider for getting a specific message by ID
/// Uses the new 3-layer architecture with proper error handling
final messageByIdProvider = FutureProvider.family<Message?, MessageId>((ref, messageId) async {
  final chatRepository = ref.read(chatRepositoryProvider);
  
  // For now, we'll search through all bases to find the message
  // In a production app, you'd have proper message indexing
  // This is a simplified implementation that searches all bases
  
  // Get all bases from the bases provider
  final basesAsync = ref.read(basesProvider);
  
  return basesAsync.when(
    data: (bases) async {
      // Search through all bases for the message
      for (final base in bases) {
        try {
          final messagesResult = await chatRepository.listMessages(
            baseId: base.id.bid,
            limit: 1000, // Large limit to search all messages
          );
          
          final messages = messagesResult.fold(
            (failure) => <Message>[],
            (messages) => messages,
          );
          
          // Find the message with matching ID
          for (final message in messages) {
            if (message.id == messageId) {
              return message;
            }
          }
        } catch (e) {
          // Continue searching other bases if one fails
          continue;
        }
      }
      
      // Message not found in any base
      return null;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});
