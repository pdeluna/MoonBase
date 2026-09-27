import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/sync_status.dart';
import 'package:moonbase_skeleton/features/chat/data/datasources/chat_outbox_local_data_source_impl.dart';
import 'package:moonbase_skeleton/features/chat/data/repositories/chat_outbox_repository_impl.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/chat_feed.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/chat_freshness.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';
import 'package:moonbase_skeleton/features/chat/domain/repositories/chat_repository.dart';
import 'package:moonbase_skeleton/features/chat/domain/usecases/send_message.dart';
import 'package:moonbase_skeleton/features/chat/domain/usecases/stream_messages.dart';
import 'package:moonbase_skeleton/features/chat/presentation/controllers/chat_controller.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_type.dart';
import 'package:moonbase_skeleton/features/media/domain/repositories/media_storage.dart';
import 'package:uuid/uuid.dart';

/// Records every `sendMessage` call and answers from a script: each entry is
/// either a `Failure` (→ `Left`) or `null` (→ `Right` echoing the request).
/// The feed is driven manually through [feed].
class _ScriptedRepo implements ChatRepository {
  final List<Object?> script = <Object?>[];
  final List<SendCall> calls = <SendCall>[];
  final StreamController<ChatFeed> feed =
      StreamController<ChatFeed>.broadcast();

  /// When non-null, sends block until completed (simulates a slow write).
  Completer<void>? gate;

  @override
  Future<Either<Failure, Message>> sendMessage({
    required BaseId baseId,
    required UserId userId,
    required String content,
    List<MediaRef> media = const [],
    MessageId? messageId,
  }) async {
    calls.add(SendCall(messageId, content, media));
    if (gate != null) await gate!.future;
    final next = script.isEmpty ? null : script.removeAt(0);
    if (next is Failure) return Left(next);
    return Right(Message(
      id: messageId ?? MessageId('server-${calls.length}'),
      baseId: baseId,
      userId: userId,
      content: content,
      createdAt: DateTime.utc(2026, 9, 27, 12),
      media: media,
    ));
  }

  @override
  Stream<ChatFeed> streamMessages(BaseId baseId) => feed.stream;

  @override
  Future<Either<Failure, List<Message>>> listMessages({
    required BaseId baseId,
    DateTime? before,
    int limit = 50,
  }) async =>
      const Right(<Message>[]);
}

class SendCall {
  SendCall(this.messageId, this.content, this.media);
  final MessageId? messageId;
  final String content;
  final List<MediaRef> media;
}

/// Text-only sends never touch media storage; fail loudly if they do.
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

/// Staging resolves to a fake URI; cloud upload records the key and returns
/// the canonical cloud path.
class _FakeMediaStorage implements MediaStorage {
  final List<String> uploads = <String>[];

  @override
  Future<String> putBytes({
    required String key,
    required List<int> bytes,
    required String mimeType,
  }) async {
    uploads.add(key);
    return 'bases/b1/media/${key.split('/').last}';
  }

  @override
  Future<String> resolveUri(String key) async => 'file:///staged/$key';

  @override
  Future<void> delete(String key) async {}
}

/// Deterministic ids so assertions can name them.
class _SeqUuid extends Uuid {
  const _SeqUuid();
  static int _n = 0;
  static void reset() => _n = 0;

  @override
  String v4({Map<String, dynamic>? options, dynamic config}) => 'local-${++_n}';
}

Message _feedMessage(String id, {String content = 'x'}) => Message(
      id: MessageId(id),
      baseId: 'b1'.bid,
      userId: 'u1'.uid,
      content: content,
      createdAt: DateTime.utc(2026, 9, 27, 12),
    );

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  late _ScriptedRepo repo;
  late InMemoryChatOutboxDataSource outboxStore;
  late ChatController c;

  ChatController build() => ChatController(
        SendMessage(
          repo,
          stagingStorage: _UnusedMediaStorage(),
          cloudStorage: _UnusedMediaStorage(),
        ),
        StreamMessages(repo),
        outbox: ChatOutboxRepositoryImpl(local: outboxStore),
        uuid: const _SeqUuid(),
        now: () => DateTime.utc(2026, 9, 27, 12, 30),
      );

  setUp(() {
    _SeqUuid.reset();
    repo = _ScriptedRepo();
    outboxStore = InMemoryChatOutboxDataSource();
    c = build();
  });

  tearDown(() async {
    await repo.feed.close();
  });

  group('send', () {
    test('appends an uploading pending entry, persists it, and never throws',
        () async {
      repo.gate = Completer<void>();
      await c.load('b1');

      await c.send('b1', 'u1', '  hello  ');

      expect(c.state.pending, hasLength(1));
      final p = c.state.pending.single;
      expect(p.id, 'local-1');
      expect(p.message.syncStatus, SyncStatus.uploading);
      expect(p.message.content, 'hello');
      expect(outboxStore.rows.map((r) => r.id), ['local-1']);
      expect(outboxStore.rows.single.syncStatus, SyncStatus.uploading);
      expect(repo.calls.single.messageId, 'local-1'.mid);

      repo.gate!.complete();
      await _settle();
      expect(c.state.pending, isEmpty);
      expect(outboxStore.rows, isEmpty);
      expect(c.state.lastSendFailure, isNull);
    });

    test(
        'Left flips the entry to failed, keeps the Failure, raises the '
        'alert event, and persists the failed status', () async {
      repo.script.add(const NetworkFailure('offline'));
      await c.load('b1');

      await c.send('b1', 'u1', 'hello');
      await _settle();

      final p = c.state.pending.single;
      expect(p.isFailed, isTrue);
      expect(p.failure, isA<NetworkFailure>());
      expect(c.state.lastSendFailure, isNotNull);
      expect(c.state.lastSendFailure!.messageId, 'local-1'.mid);
      expect(c.state.lastSendFailure!.failure.message, 'offline');
      expect(outboxStore.rows.single.syncStatus, SyncStatus.failed);
    });
  });

  group('retry', () {
    test(
        're-sends the same id and the same staged media; success removes '
        'the entry', () async {
      const media = <MediaRef>[
        MediaRef(
          id: MediaId('m0'),
          type: MediaType.image,
          storageKey: 'b1/m0.jpg',
          mimeType: 'image/jpeg',
        ),
      ];
      final storage = _FakeMediaStorage();
      repo.script.add(const NetworkFailure('first'));
      c = ChatController(
        SendMessage(
          repo,
          stagingStorage: storage,
          cloudStorage: storage,
          readStagedBytes: (_) async => Uint8List(0),
        ),
        StreamMessages(repo),
        outbox: ChatOutboxRepositoryImpl(local: outboxStore),
        uuid: const _SeqUuid(),
      );
      await c.load('b1');
      await c.send('b1', 'u1', 'look', media: media);
      await _settle();
      expect(c.state.pending.single.isFailed, isTrue);
      // The outbox row keeps the *staged* key so a replay re-uploads.
      expect(outboxStore.rows.single.media.single.storageKey, 'b1/m0.jpg');

      await c.retry('local-1');
      await _settle();

      expect(repo.calls, hasLength(2));
      expect(repo.calls.map((s) => s.messageId), everyElement('local-1'.mid));
      expect(
        repo.calls.map((s) => s.media.single.storageKey),
        everyElement('bases/b1/media/m0.jpg'),
      );
      expect(storage.uploads, ['b1/m0.jpg', 'b1/m0.jpg']);
      expect(c.state.pending, isEmpty);
      expect(outboxStore.rows, isEmpty);
    });

    test('consecutive failures raise distinct alert events', () async {
      repo.script
        ..add(const NetworkFailure('one'))
        ..add(const NetworkFailure('two'));
      await c.load('b1');
      await c.send('b1', 'u1', 'hello');
      await _settle();
      final first = c.state.lastSendFailure!;

      await c.retry('local-1');
      await _settle();
      final second = c.state.lastSendFailure!;

      expect(second, isNot(equals(first)));
      expect(second.failure.message, 'two');
      expect(c.state.pending.single.isFailed, isTrue);
    });
  });

  group('reconciliation with the live feed', () {
    test(
        'a feed document with the pending id evicts the pending entry and '
        'the outbox row (stream dedupe)', () async {
      repo.gate = Completer<void>();
      await c.load('b1');
      await c.send('b1', 'u1', 'hello');
      expect(outboxStore.rows, hasLength(1));

      repo.feed.add(ChatFeed(
        messages: [_feedMessage('local-1', content: 'hello')],
        freshness: ChatFreshness.cached,
      ));
      await _settle();

      expect(c.state.pending, isEmpty);
      expect(outboxStore.rows, isEmpty);

      repo.gate!.complete();
      await _settle();
      expect(c.state.pending, isEmpty);
    });

    test(
        'Left after the document already landed settles instead of '
        'marking failed (replay raced Firestore\'s own queue)', () async {
      repo.gate = Completer<void>();
      repo.script.add(const PermissionDeniedFailure('update denied'));
      await c.load('b1');
      await c.send('b1', 'u1', 'hello');

      // Reconciliation on the feed emission removes it first…
      repo.feed.add(ChatFeed(
        messages: [_feedMessage('local-1')],
        freshness: ChatFreshness.live,
      ));
      await _settle();
      // …then the delayed Left arrives.
      repo.gate!.complete();
      await _settle();

      expect(c.state.pending, isEmpty);
      expect(c.state.lastSendFailure, isNull);
      expect(outboxStore.rows, isEmpty);
    });
  });

  group('outbox restore (persisted variant)', () {
    test(
        'a fresh controller replays rows for the base and user, oldest '
        'first, and prunes them on success', () async {
      // Simulate a previous run that died with two queued rows.
      final first = _feedMessage('old-1', content: 'a')
          .copyWith(syncStatus: SyncStatus.failed);
      final second = _feedMessage('old-2', content: 'b')
          .copyWith(syncStatus: SyncStatus.uploading);
      final store = ChatOutboxRepositoryImpl(local: outboxStore);
      await store.upsert(first);
      await store.upsert(second);

      c = build();
      repo.gate = Completer<void>();
      await c.load('b1', userId: 'u1');

      expect(c.state.pending.map((p) => p.id), ['old-1', 'old-2']);
      expect(
        c.state.pending.map((p) => p.message.syncStatus),
        everyElement(SyncStatus.uploading),
      );
      // Sequential replay: only the first is in flight until it resolves.
      expect(repo.calls.map((s) => s.messageId), ['old-1'.mid]);

      repo.gate!.complete();
      await _settle();
      expect(repo.calls.map((s) => s.messageId), ['old-1'.mid, 'old-2'.mid]);
      expect(repo.calls.map((s) => s.content), ['a', 'b']);
      expect(c.state.pending, isEmpty);
      expect(outboxStore.rows, isEmpty);
    });

    test('rows for another user or base are left untouched', () async {
      final store = ChatOutboxRepositoryImpl(local: outboxStore);
      await store.upsert(_feedMessage('mine'));
      await store.upsert(_feedMessage('theirs').copyWith(userId: 'u2'.uid));
      await store.upsert(
        _feedMessage('elsewhere').copyWith(baseId: 'b2'.bid),
      );

      c = build();
      await c.load('b1', userId: 'u1');
      await _settle();

      expect(repo.calls.map((s) => s.messageId), ['mine'.mid]);
      expect(c.state.pending, isEmpty);
      expect(
        outboxStore.rows.map((r) => r.id).toSet(),
        {'theirs', 'elsewhere'},
      );
    });

    test('a replayed row that fails again stays failed and persisted',
        () async {
      final store = ChatOutboxRepositoryImpl(local: outboxStore);
      await store.upsert(_feedMessage('old-1'));
      repo.script.add(const NetworkFailure('still offline'));

      c = build();
      await c.load('b1', userId: 'u1');
      await _settle();

      expect(c.state.pending.single.isFailed, isTrue);
      expect(outboxStore.rows.single.syncStatus, SyncStatus.failed);
      expect(c.state.lastSendFailure, isNotNull);
    });

    test('load without a userId does not replay', () async {
      final store = ChatOutboxRepositoryImpl(local: outboxStore);
      await store.upsert(_feedMessage('old-1'));

      c = build();
      await c.load('b1');
      await _settle();

      expect(repo.calls, isEmpty);
      expect(c.state.pending, isEmpty);
      expect(outboxStore.rows, hasLength(1));
    });
  });

  test('discard drops a failed entry from state and outbox', () async {
    repo.script.add(const NetworkFailure('offline'));
    await c.load('b1');
    await c.send('b1', 'u1', 'hello');
    await _settle();
    expect(c.state.pending.single.isFailed, isTrue);

    await c.discard('local-1');

    expect(c.state.pending, isEmpty);
    expect(outboxStore.rows, isEmpty);
    expect(repo.calls, hasLength(1));
  });

  test('feed state still flows through as AsyncValue data', () async {
    await c.load('b1');
    repo.feed.add(ChatFeed(
      messages: [_feedMessage('f1'), _feedMessage('f2')],
      freshness: ChatFreshness.live,
    ));
    await _settle();
    final feed = c.state.feed;
    expect(feed, isA<AsyncData<ChatFeed>>());
    expect(feed.value!.messages, hasLength(2));
  });
}
