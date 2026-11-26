import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/sync_status.dart';
import 'package:moonbase_skeleton/features/bases/presentation/providers/sidebar_providers.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/providers/chat_memories.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/providers/stories_seam.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/viewmodels/calendar_home_vm.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/chat_feed.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/chat_freshness.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';
import 'package:moonbase_skeleton/features/chat/domain/repositories/chat_repository.dart';
import 'package:moonbase_skeleton/features/chat/presentation/providers/chat_providers.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_type.dart';

import '../../../../test_utils/fakes_calendar.dart';

void main() {
  test('photos bucket to the local day as oldest-first shares', () async {
    // kOwner is Mom and kMember is Dad. The feed is not in send order.
    final container = _container(
      ChatFeed(
        freshness: ChatFreshness.live,
        messages: [
          _message('late', DateTime(2026, 9, 20, 18)),
          _message('mom-c', DateTime(2026, 9, 22, 12)),
          _message('dad', DateTime(2026, 9, 22, 10), author: kMember),
          _message('early', DateTime(2026, 9, 20, 10)),
          _message('mom-b', DateTime(2026, 9, 22, 9, 30)),
          _message(
            'mom-a',
            DateTime(2026, 9, 22, 9),
            media: const [
              MediaRef(
                id: MediaId('mom-a1'),
                type: MediaType.image,
                storageKey: 'a1.jpg',
              ),
              MediaRef(
                id: MediaId('mom-a2'),
                type: MediaType.image,
                storageKey: 'a2.jpg',
              ),
            ],
          ),
          _message('next', DateTime(2026, 9, 21, 9)),
          _message(
            'pending',
            DateTime(2026, 9, 22, 9, 10),
            status: SyncStatus.localOnly,
          ),
          _message(
            'clip',
            DateTime(2026, 9, 22, 9, 20),
            type: MediaType.video,
          ),
        ],
      ),
    );
    addTearDown(container.dispose);

    final photos = await container.read(chatMemoriesProvider.future);
    expect(photos.keys, {
      const DayKey(2026, 9, 20),
      const DayKey(2026, 9, 21),
      const DayKey(2026, 9, 22),
    });

    final sep20 = photos[const DayKey(2026, 9, 20)]!;
    expect(sep20, hasLength(1));
    expect(sep20.single.author, kOwner);
    expect(
      sep20.single.media.map((item) => item.id.value),
      ['early', 'late'],
    );

    final sep22 = photos[const DayKey(2026, 9, 22)]!;
    expect(sep22.map((share) => share.author), [kOwner, kMember, kOwner]);
    expect(
      sep22[0].media.map((item) => item.id.value),
      ['mom-a1', 'mom-a2', 'mom-b'],
    );
    expect(sep22[1].media.map((item) => item.id.value), ['dad']);
    expect(sep22[2].media.map((item) => item.id.value), ['mom-c']);

    expect(container.read(memoryDaysProvider), photos.keys.toSet());
  });

  test('no selected base yields no memories', () async {
    final container = ProviderContainer(
      overrides: [
        effectiveSelectedBaseProvider.overrideWithValue(null),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(chatMemoriesProvider.future), isEmpty);
    expect(container.read(memoryDaysProvider), isEmpty);
  });
}

Message _message(
  String id,
  DateTime at, {
  UserId? author,
  SyncStatus status = SyncStatus.synced,
  MediaType type = MediaType.image,
  List<MediaRef>? media,
}) {
  return Message(
    id: id.mid,
    baseId: kBase.id,
    userId: author ?? kOwner,
    content: '',
    createdAt: at,
    syncStatus: status,
    media: media ??
        [
          MediaRef(id: MediaId(id), type: type, storageKey: '$id.jpg'),
        ],
  );
}

ProviderContainer _container(ChatFeed feed) {
  return ProviderContainer(
    overrides: [
      effectiveSelectedBaseProvider.overrideWithValue(kBase),
      chatRepositoryProvider.overrideWithValue(_FakeChat(feed)),
    ],
  );
}

class _FakeChat implements ChatRepository {
  _FakeChat(this.feed);

  final ChatFeed feed;

  @override
  Future<Either<Failure, List<Message>>> listMessages({
    required BaseId baseId,
    DateTime? before,
    int limit = 50,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, Message>> sendMessage({
    required BaseId baseId,
    required UserId userId,
    required String content,
    List<MediaRef> media = const [],
    MessageId? messageId,
  }) {
    throw UnimplementedError();
  }

  @override
  Stream<ChatFeed> streamMessages(BaseId baseId) => Stream.value(feed);
}
