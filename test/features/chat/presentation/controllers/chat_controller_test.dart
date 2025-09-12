import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/features/chat/data/datasources/chat_local_data_source_impl.dart';
import 'package:moonbase_skeleton/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:moonbase_skeleton/features/chat/domain/usecases/list_messages.dart';
import 'package:moonbase_skeleton/features/chat/domain/usecases/send_message.dart';
import 'package:moonbase_skeleton/features/chat/domain/usecases/stream_messages.dart';
import 'package:moonbase_skeleton/features/chat/presentation/controllers/chat_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        ListMessages(repo),
        SendMessage(repo),
        StreamMessages(repo),
      );
    });

    test('load empty then send updates via stream', () async {
      c.subscribe('b1');
      await c.load('b1');
      expect(expectData(c.state.messages), isEmpty);

      await c.send('b1', 'u1', 'hello');
      await c.send('b1', 'u2', 'world');

      // allow stream to deliver
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final list = expectData(c.state.messages);
      expect(list.map((m) => m.content).toList(), ['hello', 'world']);
    });
  });
}
