import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/send_message.dart';
import '../../domain/usecases/stream_messages.dart';
import '../../domain/usecases/list_messages.dart';

/// Override at app root with a concrete repo.
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  throw UnimplementedError('Provide ChatRepository in app wiring');
});

final sendMessageUseCaseProvider   = Provider((ref) => SendMessage(ref.read(chatRepositoryProvider)));
final streamMessagesUseCaseProvider = Provider((ref) => StreamMessages(ref.read(chatRepositoryProvider)));
final listMessagesUseCaseProvider   = Provider((ref) => ListMessages(ref.read(chatRepositoryProvider)));
