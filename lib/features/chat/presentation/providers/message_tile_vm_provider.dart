import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/features/auth/presentation/providers/current_user_id_provider.dart';
import 'package:moonbase_skeleton/features/auth/presentation/providers/member_presentation_provider.dart';
import 'package:moonbase_skeleton/features/chat/presentation/viewmodels/message_tile_vm.dart';
import 'package:moonbase_skeleton/features/chat/domain/providers/message_by_id_provider.dart';
import 'package:moonbase_skeleton/core/ids.dart';

/// Provider for message tile view model using the new 3-layer architecture
final messageTileVmProvider = Provider.family<MessageTileVM?, MessageId>((ref, messageId) {
  final currentUserId = ref.watch(currentUserIdProvider);
  
  // Get the message using the new architecture
  final messageAsync = ref.watch(messageByIdProvider(messageId));
  
  return messageAsync.when(
    data: (message) {
      if (message == null) return null;
      
      // Get member presentation (nickname + color) for the message author
      final member = ref.watch(memberPresentationProvider(message.userId.value));
      
      return MessageTileVM(
        id: message.id.value,
        text: message.content,
        sentAt: message.createdAt,
        isMine: (currentUserId != null && currentUserId == message.userId.value),
        nickname: member.nickname,
        nameColor: member.nameColor,
        avatarUrl: null, // Not available in current message model
      );
    },
    loading: () => null,
    error: (_, __) => null,
  );
});
