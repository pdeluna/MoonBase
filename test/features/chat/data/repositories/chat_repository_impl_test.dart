import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/presentation/failure_presenter.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/chat/data/datasources/chat_local_data_source.dart';
import 'package:moonbase_skeleton/features/chat/data/datasources/chat_local_data_source_impl.dart';
import 'package:moonbase_skeleton/features/chat/data/models/chat_message_batch.dart';
import 'package:moonbase_skeleton/features/chat/data/models/message_model.dart';
import 'package:moonbase_skeleton/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/chat_feed.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/chat_freshness.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_type.dart';

class _StubBatchDs implements ChatLocalDataSource {
  _StubBatchDs(this._batches);

  final Stream<ChatMessageBatch> _batches;

  @override
  Stream<ChatMessageBatch> streamMessages(String baseId) => _batches;

  @override
  Future<MessageModel> sendMessage({
    required String baseId,
    required String userId,
    required String content,
    List<MediaRef> media = const [],
    String? messageId,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<MessageModel>> listMessages({
    required String baseId,
    DateTime? before,
    int limit = 50,
  }) =>
      throw UnimplementedError();
}

void main() {
  group('ChatRepositoryImpl + InMemory DS', () {
    test('sendMessage then listMessages returns the message', () async {
      final ds = InMemoryChatLocalDataSource();
      final repo = ChatRepositoryImpl(local: ds);

      final sent = await repo.sendMessage(
          baseId: 'b1'.bid, userId: 'u1'.uid, content: 'hi');
      expect(sent, isA<Right<Failure, Message>>());
      final msg = (sent as Right<Failure, Message>).value;
      expect(msg.content, 'hi');

      final listed = await repo.listMessages(baseId: 'b1'.bid);
      final list = (listed as Right<Failure, List<Message>>).value;
      expect(list.length, 1);
      expect(list.single.id, msg.id);
    });

    test('streamMessages emits on new messages', () async {
      final ds = InMemoryChatLocalDataSource();
      final repo = ChatRepositoryImpl(local: ds);

      final stream = repo.streamMessages('b1'.bid);
      final events = <ChatFeed>[];
      final sub = stream.listen(events.add);

      await repo.sendMessage(
          baseId: 'b1'.bid, userId: 'u1'.uid, content: 'one');
      await repo.sendMessage(
          baseId: 'b1'.bid, userId: 'u2'.uid, content: 'two');

      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();

      expect(events.isNotEmpty, true);
      expect(
          events.last.messages.map((m) => m.content).toList(), ['one', 'two']);
      expect(events.last.freshness, ChatFreshness.live);
    });

    test('fromCache true maps to ChatFreshness.cached', () async {
      final batches = StreamController<ChatMessageBatch>();
      final repo = ChatRepositoryImpl(local: _StubBatchDs(batches.stream));
      final events = <ChatFeed>[];
      final sub = repo.streamMessages('b1'.bid).listen(events.add);

      batches.add(const ChatMessageBatch(messages: [], fromCache: true));
      await Future<void>.delayed(Duration.zero);
      expect(events.single.freshness, ChatFreshness.cached);

      batches.add(const ChatMessageBatch(messages: [], fromCache: false));
      await Future<void>.delayed(Duration.zero);
      expect(events.last.freshness, ChatFreshness.live);

      await sub.cancel();
      await batches.close();
    });

    test('sendMessage carries media through to the persisted entity', () async {
      final ds = InMemoryChatLocalDataSource();
      final repo = ChatRepositoryImpl(local: ds);

      final media = <MediaRef>[
        const MediaRef(
          id: MediaId('img_0'),
          type: MediaType.image,
          storageKey: 'b1/img_0.jpg',
          sizeBytes: 4096,
          mimeType: 'image/jpeg',
        ),
        const MediaRef(
          id: MediaId('vid_0'),
          type: MediaType.video,
          storageKey: 'b1/vid_0.mp4',
          duration: Duration(seconds: 8),
          sizeBytes: 2000000,
          mimeType: 'video/mp4',
        ),
      ];

      final sent = await repo.sendMessage(
        baseId: 'b1'.bid,
        userId: 'u1'.uid,
        content: 'look',
        media: media,
      );

      expect(sent, isA<Right<Failure, Message>>());
      final msg = (sent as Right<Failure, Message>).value;
      expect(msg.media.length, 2);
      expect(msg.media.first.type, MediaType.image);
      expect(msg.media.last.duration, const Duration(seconds: 8));

      final listed = await repo.listMessages(baseId: 'b1'.bid);
      final list = (listed as Right<Failure, List<Message>>).value;
      expect(list.single.media.length, 2);
      expect(list.single.media.map((m) => m.storageKey).toList(),
          ['b1/img_0.jpg', 'b1/vid_0.mp4']);
    });

    test('sendMessage honours a client-chosen messageId (outbox retry)',
        () async {
      final ds = InMemoryChatLocalDataSource();
      final repo = ChatRepositoryImpl(local: ds);

      final sent = await repo.sendMessage(
        baseId: 'b1'.bid,
        userId: 'u1'.uid,
        content: 'hi',
        messageId: 'client-uuid-1'.mid,
      );

      final msg = (sent as Right<Failure, Message>).value;
      expect(msg.id, 'client-uuid-1'.mid);
      final listed = await repo.listMessages(baseId: 'b1'.bid);
      final list = (listed as Right<Failure, List<Message>>).value;
      expect(list.single.id, 'client-uuid-1'.mid);
    });
  });

  group('unacknowledged local writes (S1 B-c)', () {
    MessageModel model(String id, String content) => MessageModel(
          id: id,
          baseId: 'b1',
          userId: 'u1',
          content: content,
          createdAt: DateTime.utc(2026, 9, 27, 12),
        );

    test('cache echo is dropped from the feed; freshness stays cached',
        () async {
      final batches = StreamController<ChatMessageBatch>();
      final repo = ChatRepositoryImpl(local: _StubBatchDs(batches.stream));
      final events = <ChatFeed>[];
      final sub = repo.streamMessages('b1'.bid).listen(events.add);

      batches.add(ChatMessageBatch(
        messages: [model('old', 'earlier'), model('local-1', 'hello')],
        fromCache: true,
        unacknowledgedIds: const {'local-1'},
      ));
      await Future<void>.delayed(Duration.zero);

      expect(events.single.freshness, ChatFreshness.cached);
      expect(events.single.messages.map((m) => m.id.value), ['old']);
      expect(events.single.messages.single.content, 'earlier');

      await sub.cancel();
      await batches.close();
    });

    test('a send that never gets a server ack fails with plain network copy',
        () {
      fakeAsync((async) {
        final repo = ChatRepositoryImpl(local: _HangingChatDs());
        late Either<Failure, Message> result;
        repo
            .sendMessage(baseId: 'b1'.bid, userId: 'u1'.uid, content: 'hi')
            .then((r) => result = r);

        async.elapse(kChatSendAckTimeout);
        async.flushMicrotasks();

        final failure = result.match((f) => f, (_) => fail('expected Left'));
        expect(failure, isA<NetworkFailure>());
        expect(
          failure.message,
          'Chat send was not acknowledged by the server.',
        );
        expect(userMessage(failure), kNetworkErrorCopy);
        expect(userMessage(failure), isNot(contains('acknowledged')));
      });
    });
  });
}

class _HangingChatDs implements ChatLocalDataSource {
  @override
  Future<MessageModel> sendMessage({
    required String baseId,
    required String userId,
    required String content,
    List<MediaRef> media = const [],
    String? messageId,
  }) =>
      Completer<MessageModel>().future;

  @override
  Stream<ChatMessageBatch> streamMessages(String baseId) =>
      const Stream.empty();

  @override
  Future<List<MessageModel>> listMessages({
    required String baseId,
    DateTime? before,
    int limit = 50,
  }) =>
      Completer<List<MessageModel>>().future;
}
