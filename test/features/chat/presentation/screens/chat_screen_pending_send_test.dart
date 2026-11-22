import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/presentation/failure_presenter.dart';
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
import 'package:moonbase_skeleton/features/chat/presentation/widgets/cached_messages_banner.dart';
import 'package:moonbase_skeleton/features/chat/presentation/widgets/message_bubble.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/domain/repositories/media_storage.dart';
import 'package:moonbase_skeleton/features/reactions/data/datasources/reaction_data_source_impl.dart';
import 'package:moonbase_skeleton/features/reactions/data/repositories/reaction_repository_impl.dart';
import 'package:moonbase_skeleton/features/reactions/presentation/providers/reaction_providers.dart';

/// First send fails after [gate] opens; later sends succeed and echo into
/// the feed like Firestore would.
class _FailThenSucceedRepo implements ChatRepository {
  final List<MessageId?> sentIds = <MessageId?>[];
  final Completer<void> gate = Completer<void>();
  final StreamController<ChatFeed> feed =
      StreamController<ChatFeed>.broadcast();
  final List<Message> delivered = <Message>[];

  @override
  Future<Either<Failure, Message>> sendMessage({
    required BaseId baseId,
    required UserId userId,
    required String content,
    List<MediaRef> media = const [],
    MessageId? messageId,
  }) async {
    sentIds.add(messageId);
    if (sentIds.length == 1) {
      await gate.future;
      return const Left(NetworkFailure('No connection'));
    }
    final m = Message(
      id: messageId!,
      baseId: baseId,
      userId: userId,
      content: content,
      createdAt: DateTime.utc(2026, 9, 27, 12),
    );
    delivered.add(m);
    feed.add(ChatFeed(messages: delivered, freshness: ChatFreshness.live));
    return Right(m);
  }

  @override
  Stream<ChatFeed> streamMessages(BaseId baseId) async* {
    yield const ChatFeed(messages: [], freshness: ChatFreshness.live);
    yield* feed.stream;
  }

  @override
  Future<Either<Failure, List<Message>>> listMessages({
    required BaseId baseId,
    DateTime? before,
    int limit = 50,
  }) async =>
      const Right(<Message>[]);
}

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
      'failed send: composer clears at once, pending bubble spins, then '
      'flips to failed with an alert; tap resends once and the bubble '
      'settles', (tester) async {
    final repo = _FailThenSucceedRepo();
    final outbox = InMemoryChatOutboxDataSource();
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
          reactionRepositoryProvider.overrideWithValue(
            ReactionRepositoryImpl(source: InMemoryReactionDataSource()),
          ),
          effectiveSelectedBaseProvider.overrideWith((ref) => base),
          currentUserProvider
              .overrideWith((ref) => const AsyncValue<User?>.data(user)),
          basesListProvider.overrideWith((ref) async => [base]),
          memberPresentationProvider.overrideWith(
            (ref, id) => const MemberPresentation(
              nickname: 'kiddo',
              nameColor: Colors.blue,
            ),
          ),
          chatControllerProvider.overrideWith((ref) => ChatController(
                SendMessage(
                  repo,
                  stagingStorage: _UnusedMediaStorage(),
                  cloudStorage: _UnusedMediaStorage(),
                ),
                StreamMessages(repo),
                outbox: ChatOutboxRepositoryImpl(local: outbox),
              )),
        ],
        child: const MaterialApp(home: ChatScreen()),
      ),
    );
    await tester.pump(); // post-frame load()
    await tester.pump(); // first feed emission

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();

    // Clear-on-send + pending bubble with spinner while the write hangs.
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(repo.sentIds, hasLength(1));
    final id = repo.sentIds.single!.value;
    expect(find.text('hello'), findsOneWidget);
    expect(find.byKey(MessageBubble.pendingKey(id)), findsOneWidget);
    expect(find.text('Sending…'), findsOneWidget);
    expect(outbox.rows.map((r) => r.id), [id]);

    // Write fails → failed flag + alert, message still on screen.
    repo.gate.complete();
    await tester.pump();
    await tester.pump();
    expect(find.byKey(MessageBubble.failedKey(id)), findsOneWidget);
    expect(find.text('Not sent · Tap to resend'), findsOneWidget);
    expect(find.text('Message not sent: $kNetworkErrorCopy'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.text('hello'), findsOneWidget);

    // Tap the bubble → exactly one more send with the same id; the feed
    // echo dedupes the pending copy and the bubble renders as synced.
    await tester.tap(find.text('hello'));
    await tester.pump();
    await tester.pump();
    expect(repo.sentIds, hasLength(2));
    expect(repo.sentIds.last!.value, id);
    expect(find.text('hello'), findsOneWidget);
    expect(find.byKey(MessageBubble.pendingKey(id)), findsNothing);
    expect(find.byKey(MessageBubble.failedKey(id)), findsNothing);
    expect(outbox.rows, isEmpty);

    await tester.pump(const Duration(seconds: 7)); // let the snackbar close
    await repo.feed.close();
  });

  testWidgets(
      'airplane send: cached banner stays a history hint; the failed bubble '
      'and Retry alert still show', (tester) async {
    final repo = _CachedHistoryThenFailRepo();
    final outbox = InMemoryChatOutboxDataSource();
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
          reactionRepositoryProvider.overrideWithValue(
            ReactionRepositoryImpl(source: InMemoryReactionDataSource()),
          ),
          effectiveSelectedBaseProvider.overrideWith((ref) => base),
          currentUserProvider
              .overrideWith((ref) => const AsyncValue<User?>.data(user)),
          basesListProvider.overrideWith((ref) async => [base]),
          memberPresentationProvider.overrideWith(
            (ref, id) => const MemberPresentation(
              nickname: 'kiddo',
              nameColor: Colors.blue,
            ),
          ),
          chatControllerProvider.overrideWith((ref) => ChatController(
                SendMessage(
                  repo,
                  stagingStorage: _UnusedMediaStorage(),
                  cloudStorage: _UnusedMediaStorage(),
                ),
                StreamMessages(repo),
                outbox: ChatOutboxRepositoryImpl(local: outbox),
              )),
        ],
        child: const MaterialApp(home: ChatScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(CachedMessagesBanner.delay);

    expect(find.text(CachedMessagesBanner.copy), findsOneWidget);
    expect(find.text('earlier'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    final id = repo.sentIds.single!.value;
    expect(find.byKey(MessageBubble.pendingKey(id)), findsOneWidget);
    expect(find.text('Sending…'), findsOneWidget);
    expect(find.text('hello'), findsOneWidget);
    // The history banner is not the send-failure surface.
    expect(find.text('Not sent · Tap to resend'), findsNothing);

    repo.gate.complete();
    await tester.pump();
    await tester.pump();

    expect(find.byKey(MessageBubble.failedKey(id)), findsOneWidget);
    expect(find.text('Not sent · Tap to resend'), findsOneWidget);
    expect(find.text('Message not sent: $kNetworkErrorCopy'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('hello'), findsOneWidget);
    expect(find.text(CachedMessagesBanner.copy), findsOneWidget);
    expect(outbox.rows.single.syncStatus.name, 'failed');

    await tester.pump(const Duration(seconds: 7));
    await repo.feed.close();
  });
}

/// Cached history is already on screen. The send fails without the new
/// message ever appearing in the feed — that is what the repository does
/// with a Firestore local echo (`hasPendingWrites`).
class _CachedHistoryThenFailRepo implements ChatRepository {
  final List<MessageId?> sentIds = <MessageId?>[];
  final Completer<void> gate = Completer<void>();
  final StreamController<ChatFeed> feed =
      StreamController<ChatFeed>.broadcast();

  static final Message _older = Message(
    id: const MessageId('old'),
    baseId: const BaseId('b1'),
    userId: const UserId('u1'),
    content: 'earlier',
    createdAt: DateTime.utc(2026, 9, 27, 11),
  );

  @override
  Future<Either<Failure, Message>> sendMessage({
    required BaseId baseId,
    required UserId userId,
    required String content,
    List<MediaRef> media = const [],
    MessageId? messageId,
  }) async {
    sentIds.add(messageId);
    await gate.future;
    return const Left(NetworkFailure('offline'));
  }

  @override
  Stream<ChatFeed> streamMessages(BaseId baseId) async* {
    yield ChatFeed(messages: [_older], freshness: ChatFreshness.cached);
    yield* feed.stream;
  }

  @override
  Future<Either<Failure, List<Message>>> listMessages({
    required BaseId baseId,
    DateTime? before,
    int limit = 50,
  }) async =>
      const Right(<Message>[]);
}
