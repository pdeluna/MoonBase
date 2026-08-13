import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/chat/data/datasources/chat_local_data_source_impl.dart';
import 'package:moonbase_skeleton/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/chat_feed.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/chat_freshness.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';
import 'package:moonbase_skeleton/features/chat/domain/repositories/chat_repository.dart';
import 'package:moonbase_skeleton/features/chat/domain/usecases/send_message.dart';
import 'package:moonbase_skeleton/features/chat/domain/usecases/stream_messages.dart';
import 'package:moonbase_skeleton/features/chat/presentation/controllers/chat_controller.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/domain/repositories/media_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class _SilentStreamRepo implements ChatRepository {
  final controller = StreamController<ChatFeed>();

  @override
  Stream<ChatFeed> streamMessages(BaseId baseId) => controller.stream;

  @override
  Future<Either<Failure, List<Message>>> listMessages({
    required BaseId baseId,
    DateTime? before,
    int limit = 50,
  }) async =>
      const Right(<Message>[]);

  @override
  Future<Either<Failure, Message>> sendMessage({
    required BaseId baseId,
    required UserId userId,
    required String content,
    List<MediaRef> media = const [],
  }) =>
      throw UnimplementedError();
}

void main() {
  group('ChatController with in-memory repo', () {
    late InMemoryChatLocalDataSource ds;
    late ChatRepositoryImpl repo;
    late ChatController c;

    T expectData<T>(AsyncValue<T> av) => av.when(
          data: (v) => v,
          loading: () => fail('expected data, got loading'),
          error: (e, st) => fail('expected data, got error: $e'),
        );

    setUp(() {
      ds = InMemoryChatLocalDataSource();
      repo = ChatRepositoryImpl(local: ds);
      c = ChatController(
        SendMessage(
          repo,
          stagingStorage: _UnusedMediaStorage(),
          cloudStorage: _UnusedMediaStorage(),
        ),
        StreamMessages(repo),
      );
    });

    test('load empty then send updates via stream', () async {
      await c.load('b1');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final empty = expectData(c.state.feed);
      expect(empty.messages, isEmpty);
      expect(empty.freshness, ChatFreshness.live);

      await c.send('b1', 'u1', 'hello');
      await c.send('b1', 'u2', 'world');

      // allow stream to deliver
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final feed = expectData(c.state.feed);
      // Controller keeps newest first so ListView(reverse: true) shows newest at bottom
      expect(feed.messages.map((m) => m.content).toList(), ['world', 'hello']);
      expect(feed.freshness, ChatFreshness.live);
    });
  });

  test('load stays loading until the stream emits', () async {
    final repo = _SilentStreamRepo();
    final c = ChatController(
      SendMessage(
        repo,
        stagingStorage: _UnusedMediaStorage(),
        cloudStorage: _UnusedMediaStorage(),
      ),
      StreamMessages(repo),
    );

    await c.load('b1');
    expect(c.state.feed.isLoading, isTrue);

    repo.controller.add(
      const ChatFeed(messages: [], freshness: ChatFreshness.cached),
    );
    await Future<void>.delayed(Duration.zero);

    final feed = c.state.feed.when(
      data: (v) => v,
      loading: () => fail('expected data, got loading'),
      error: (e, st) => fail('expected data, got error: $e'),
    );
    expect(feed.freshness, ChatFreshness.cached);

    await repo.controller.close();
    c.dispose();
  });
}
