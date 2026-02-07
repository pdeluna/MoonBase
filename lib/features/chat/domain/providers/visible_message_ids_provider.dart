import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/features/chat/presentation/providers/chat_providers.dart';
import 'package:moonbase_skeleton/core/ids.dart';

/// Provider for getting visible message IDs for a specific base
/// Uses the new 3-layer architecture with proper error handling
final visibleMessageIdsProvider = FutureProvider.family<List<MessageId>, BaseId>((ref, baseId) async {
  final chatRepository = ref.read(chatRepositoryProvider);
  
  final messagesResult = await chatRepository.listMessages(
    baseId: baseId,
    limit: 50, // Reasonable limit for visible messages
  );
  
  return messagesResult.fold(
    (failure) => <MessageId>[], // Return empty list on failure
    (messages) => messages.map((m) => m.id).toList(),
  );
});
