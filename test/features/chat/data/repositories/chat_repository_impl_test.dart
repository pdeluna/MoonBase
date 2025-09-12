import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/features/chat/data/datasources/chat_local_data_source_impl.dart';
import 'package:moonbase_skeleton/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';
import 'package:moonbase_skeleton/core/ids.dart';

void main() {
  group('ChatRepositoryImpl + InMemory DS', () {
    test('sendMessage then listMessages returns the message', () async {
      final ds = InMemoryChatLocalDataSource();
      final repo = ChatRepositoryImpl(local: ds);

      final sent = await repo.sendMessage(baseId: 'b1'.bid, userId: 'u1'.uid, content: 'hi');
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
      final events = <List<Message>>[];
      final sub = stream.listen(events.add);

      await repo.sendMessage(baseId: 'b1'.bid, userId: 'u1'.uid, content: 'one');
      await repo.sendMessage(baseId: 'b1'.bid, userId: 'u2'.uid, content: 'two');

      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();

      expect(events.isNotEmpty, true);
      expect(events.last.map((m) => m.content).toList(), ['one', 'two']);
    });
  });
}
