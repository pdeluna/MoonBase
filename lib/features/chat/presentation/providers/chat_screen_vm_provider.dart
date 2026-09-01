import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/features/chat/presentation/viewmodels/chat_screen_vm.dart';
import 'package:moonbase_skeleton/features/chat/presentation/controllers/chat_controller.dart';
import 'package:moonbase_skeleton/features/auth/presentation/providers/auth_providers.dart';
import 'package:moonbase_skeleton/features/bases/presentation/providers/sidebar_providers.dart';

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

  return chatState.feed.when(
    data: (feed) => ChatScreenVM(
      selectedBase: baseEntity,
      currentUser: currentUser,
      messages: feed.messages,
      isLoading: false,
      error: null,
      canSendMessage: canSend,
      freshness: feed.freshness,
    ),
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
      error: error.toString(),
      canSendMessage: canSend,
    ),
  );
});
