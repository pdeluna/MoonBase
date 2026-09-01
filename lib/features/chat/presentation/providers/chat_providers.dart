import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/features/chat/domain/repositories/chat_repository.dart';
import 'package:moonbase_skeleton/features/chat/domain/usecases/send_message.dart';
import 'package:moonbase_skeleton/features/chat/domain/usecases/stream_messages.dart';
import 'package:moonbase_skeleton/features/chat/domain/usecases/list_messages.dart';
import 'package:moonbase_skeleton/features/media/presentation/providers/media_providers.dart';

/// Override at app root with a concrete repo.
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  throw UnimplementedError('Provide ChatRepository in app wiring');
});

/// `SendMessage` orchestrates upload-then-create (Week 5 task 3 pass 2), so
/// it takes the staging storage (where the picker persisted bytes) and the
/// cloud storage (compress + upload) alongside the chat repo.
final sendMessageUseCaseProvider = Provider((ref) => SendMessage(
      ref.read(chatRepositoryProvider),
      stagingStorage: ref.read(mediaStorageProvider),
      cloudStorage: ref.read(cloudMediaStorageProvider),
    ));
final streamMessagesUseCaseProvider = Provider((ref) => StreamMessages(ref.read(chatRepositoryProvider)));
final listMessagesUseCaseProvider   = Provider((ref) => ListMessages(ref.read(chatRepositoryProvider)));
