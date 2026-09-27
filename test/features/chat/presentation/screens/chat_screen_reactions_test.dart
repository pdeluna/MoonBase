import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/auth/domain/entities/user.dart';
import 'package:moonbase_skeleton/features/auth/presentation/providers/auth_providers.dart';
import 'package:moonbase_skeleton/features/auth/presentation/providers/member_presentation_provider.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/bases/presentation/providers/sidebar_providers.dart';
import 'package:moonbase_skeleton/features/chat/data/datasources/chat_outbox_local_data_source_impl.dart';
import 'package:moonbase_skeleton/features/chat/data/repositories/chat_outbox_repository_impl.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/chat_feed.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/chat_freshness.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';
import 'package:moonbase_skeleton/features/chat/domain/repositories/chat_repository.dart';
import 'package:moonbase_skeleton/features/chat/domain/usecases/send_message.dart';
import 'package:moonbase_skeleton/features/chat/domain/usecases/stream_messages.dart';
import 'package:moonbase_skeleton/features/chat/presentation/controllers/chat_controller.dart';
import 'package:moonbase_skeleton/features/chat/presentation/screens/chat_screen.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/domain/repositories/media_storage.dart';
import 'package:moonbase_skeleton/features/reactions/data/datasources/reaction_data_source_impl.dart';
import 'package:moonbase_skeleton/features/reactions/data/repositories/reaction_repository_impl.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_feed.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_kind.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_target.dart';
import 'package:moonbase_skeleton/features/reactions/domain/repositories/reaction_repository.dart';
import 'package:moonbase_skeleton/features/reactions/presentation/providers/reaction_providers.dart';
import 'package:moonbase_skeleton/features/reactions/presentation/widgets/reaction_chip_row.dart';
import 'package:moonbase_skeleton/features/reactions/presentation/widgets/reaction_picker_sheet.dart';

class _FixedFeedRepo implements ChatRepository {
  _FixedFeedRepo(this.messages);
  final List<Message> messages;

  @override
  Stream<ChatFeed> streamMessages(BaseId baseId) =>
      Stream.value(ChatFeed(messages: messages, freshness: ChatFreshness.live));

  @override
  Future<Either<Failure, Message>> sendMessage({
    required BaseId baseId,
    required UserId userId,
    required String content,
    List<MediaRef> media = const [],
    MessageId? messageId,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, List<Message>>> listMessages({
    required BaseId baseId,
    DateTime? before,
    int limit = 50,
  }) async =>
      const Right(<Message>[]);
}

/// Real in-memory repo whose writes can be forced to fail.
class _FlakyReactionRepo implements ReactionRepository {
  _FlakyReactionRepo()
      : _inner = ReactionRepositoryImpl(
          source: InMemoryReactionDataSource(),
        );
  final ReactionRepositoryImpl _inner;
  Failure? failWith;

  @override
  Future<Either<Failure, void>> react({
    required BaseId baseId,
    required ReactionTarget target,
    required UserId userId,
    required ReactionKind kind,
  }) async {
    if (failWith != null) return Left(failWith!);
    return _inner.react(
        baseId: baseId, target: target, userId: userId, kind: kind);
  }

  @override
  Future<Either<Failure, void>> unreact({
    required BaseId baseId,
    required ReactionTarget target,
    required UserId userId,
  }) async {
    if (failWith != null) return Left(failWith!);
    return _inner.unreact(baseId: baseId, target: target, userId: userId);
  }

  @override
  Stream<ReactionFeed> watchFor({
    required BaseId baseId,
    required ReactionTargetKind targetKind,
  }) =>
      _inner.watchFor(baseId: baseId, targetKind: targetKind);
}

class _UnusedMediaStorage implements MediaStorage {
  @override
  Future<String> putBytes({
    required String key,
    required List<int> bytes,
    required String mimeType,
  }) =>
      throw StateError('unused');

  @override
  Future<String> resolveUri(String key) => throw StateError('unused');

  @override
  Future<void> delete(String key) => throw StateError('unused');
}

void main() {
  testWidgets(
      'long-press → pick heart → chip appears (optimistic then live); same '
      'kind again removes; a failing write rolls back and alerts',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    final base = Base(
      id: const BaseId('b1'),
      name: 'Base 1',
      ownerUserId: const UserId('u1'),
      createdAt: DateTime(2026),
    );
    const me = User(id: UserId('me'), nickname: 'kiddo');
    final message = Message(
      id: const MessageId('m1'),
      baseId: 'b1'.bid,
      userId: 'u1'.uid,
      content: 'hello',
      createdAt: DateTime.utc(2026, 9, 27),
    );
    final chatRepo = _FixedFeedRepo([message]);
    final reactionRepo = _FlakyReactionRepo();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          effectiveSelectedBaseProvider.overrideWith((ref) => base),
          currentUserProvider
              .overrideWith((ref) => const AsyncValue<User?>.data(me)),
          basesListProvider.overrideWith((ref) async => [base]),
          memberPresentationProvider.overrideWith(
            (ref, id) => const MemberPresentation(
              nickname: 'alice',
              nameColor: Colors.blue,
            ),
          ),
          reactionRepositoryProvider.overrideWithValue(reactionRepo),
          chatControllerProvider.overrideWith((ref) => ChatController(
                SendMessage(
                  chatRepo,
                  stagingStorage: _UnusedMediaStorage(),
                  cloudStorage: _UnusedMediaStorage(),
                ),
                StreamMessages(chatRepo),
                outbox: ChatOutboxRepositoryImpl(
                  local: InMemoryChatOutboxDataSource(),
                ),
              )),
        ],
        child: const MaterialApp(home: ChatScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('hello'), findsOneWidget);
    expect(find.byType(ReactionChipRow), findsNothing);

    // R1: long-press → picker → heart.
    await tester.longPress(find.text('hello'));
    await tester.pumpAndSettle();
    expect(find.byType(ReactionPickerSheet), findsOneWidget);
    await tester
        .tap(find.byKey(ReactionPickerSheet.optionKey(ReactionKind.heart)));
    await tester.pumpAndSettle();

    final heartChip = find.byKey(ReactionChipRow.chipKey(ReactionKind.heart));
    expect(heartChip, findsOneWidget);
    expect(tester.getSemantics(heartChip).label, contains('you reacted'));

    // R2: replace with fire via the picker — heart chip goes, fire count 1.
    await tester.longPress(find.text('hello'));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(ReactionPickerSheet.optionKey(ReactionKind.fire)));
    await tester.pumpAndSettle();
    expect(heartChip, findsNothing);
    expect(
        find.byKey(ReactionChipRow.chipKey(ReactionKind.fire)), findsOneWidget);

    // R3: tap the fire chip → toggle off → row disappears.
    await tester.tap(find.byKey(ReactionChipRow.chipKey(ReactionKind.fire)));
    await tester.pumpAndSettle();
    expect(find.byType(ReactionChipRow), findsNothing);

    // Rollback: write fails → chip never sticks, plain alert shown.
    reactionRepo.failWith = const NetworkFailure('No connection');
    await tester.longPress(find.text('hello'));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(ReactionPickerSheet.optionKey(ReactionKind.wow)));
    await tester.pumpAndSettle();
    expect(find.byKey(ReactionChipRow.chipKey(ReactionKind.wow)), findsNothing);
    expect(
        find.text('Couldn\'t update reaction: No connection'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);

    await tester.pump(const Duration(seconds: 5));
    semanticsHandle.dispose();
  });
}
