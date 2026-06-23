import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/chat/data/datasources/chat_local_data_source_impl.dart';
import 'package:moonbase_skeleton/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_type.dart';

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

    test('sendMessage carries media through to the persisted entity',
        () async {
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
  });
}
