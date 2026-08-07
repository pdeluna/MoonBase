import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/sync_status.dart';
import 'package:moonbase_skeleton/features/auth/domain/entities/user.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/bases/presentation/providers/sidebar_providers.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';
import 'package:moonbase_skeleton/features/chat/domain/repositories/chat_repository.dart';
import 'package:moonbase_skeleton/features/chat/domain/usecases/list_messages.dart';
import 'package:moonbase_skeleton/features/chat/domain/usecases/send_message.dart';
import 'package:moonbase_skeleton/features/chat/domain/usecases/stream_messages.dart';
import 'package:moonbase_skeleton/features/chat/presentation/controllers/chat_controller.dart';
import 'package:moonbase_skeleton/features/chat/presentation/providers/chat_screen_vm_provider.dart';
import 'package:moonbase_skeleton/features/chat/presentation/screens/chat_screen.dart';
import 'package:moonbase_skeleton/features/chat/presentation/viewmodels/chat_screen_vm.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/domain/repositories/media_storage.dart';

/// Counts `sendMessage` calls and holds each one open until [gate] completes,
/// simulating the slow compress + upload + create that Week 5 task 3 pass 2
/// puts in front of the message write.
class _SlowCountingChatRepo implements ChatRepository {
  int sendCalls = 0;
  final Completer<void> gate = Completer<void>();

  @override
  Future<Either<Failure, Message>> sendMessage({
    required BaseId baseId,
    required UserId userId,
    required String content,
    List<MediaRef> media = const [],
  }) async {
    sendCalls++;
    await gate.future;
    return Right(Message(
      id: MessageId('m$sendCalls'),
      baseId: baseId,
      userId: userId,
      content: content,
      createdAt: DateTime(2026, 8, 6),
      media: media,
      syncStatus: SyncStatus.synced,
    ));
  }

  @override
  Stream<List<Message>> streamMessages(BaseId baseId) =>
      const Stream<List<Message>>.empty();

  @override
  Future<Either<Failure, List<Message>>> listMessages({
    required BaseId baseId,
    DateTime? before,
    int limit = 50,
  }) async =>
      const Right(<Message>[]);
}

/// Text-only sends never reach media storage; fail loudly if they do.
class _UnusedMediaStorage implements MediaStorage {
  @override
  Future<String> putBytes({
    required String key,
    required List<int> bytes,
    required String mimeType,
  }) =>
      throw StateError('MediaStorage must not be touched in this test');

  @override
  Future<String> resolveUri(String key) =>
      throw StateError('MediaStorage must not be touched in this test');

  @override
  Future<void> delete(String key) =>
      throw StateError('MediaStorage must not be touched in this test');
}

void main() {
  testWidgets(
      'double-send guard: while a send is in flight the send button is '
      'disabled and a second tap creates no second message', (tester) async {
    final repo = _SlowCountingChatRepo();
    final base = Base(
      id: const BaseId('b1'),
      name: 'Base 1',
      ownerUserId: const UserId('u1'),
      createdAt: DateTime(2026),
    );
    const user = User(id: UserId('u1'), nickname: 'kiddo');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatScreenVmProvider.overrideWithValue(ChatScreenVM(
            selectedBase: base,
            currentUser: user,
            messages: const [],
            isLoading: false,
            error: null,
            canSendMessage: true,
          )),
          chatControllerProvider.overrideWith((ref) => ChatController(
                ListMessages(repo),
                SendMessage(
                  repo,
                  stagingStorage: _UnusedMediaStorage(),
                  cloudStorage: _UnusedMediaStorage(),
                ),
                StreamMessages(repo),
              )),
          effectiveSelectedBaseProvider.overrideWith((ref) => null),
        ],
        child: const MaterialApp(home: ChatScreen()),
      ),
    );
    await tester.pump(); // post-frame load()

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();

    FloatingActionButton fab() =>
        tester.widget<FloatingActionButton>(find.byType(FloatingActionButton));
    expect(fab().onPressed, isNotNull);

    // First tap: send goes in flight (repo holds the future open).
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    expect(repo.sendCalls, 1);

    // In-flight: the existing disable affordance kicks in — button greyed.
    expect(fab().onPressed, isNull);

    // Second tap while in flight must be a no-op.
    await tester.tap(find.byType(FloatingActionButton), warnIfMissed: false);
    await tester.pump();
    expect(repo.sendCalls, 1);

    // Release the send; exactly one message was created, composer cleared.
    repo.gate.complete();
    await tester.pumpAndSettle();
    expect(repo.sendCalls, 1);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });
}
