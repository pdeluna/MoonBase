import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/bases/presentation/providers/sidebar_providers.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/viewmodels/calendar_home_vm.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/chat_feed.dart';
import 'package:moonbase_skeleton/features/chat/presentation/providers/chat_providers.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_type.dart';

/// Consecutive persisted image messages on one local day by one author.
///
/// [media] keeps send order.
@immutable
class DayShare {
  const DayShare({required this.author, required this.media});

  final UserId author;
  final List<MediaRef> media;
}

/// Chat images for the selected base, one list of shares per local day.
///
/// Shares are oldest first. Back-to-back image messages from the same person
/// on that day are one share.
final chatMemoriesProvider = StreamProvider<Map<DayKey, List<DayShare>>>((ref) {
  final base = ref.watch(effectiveSelectedBaseProvider);
  if (base == null) {
    return Stream<Map<DayKey, List<DayShare>>>.value(const {});
  }
  return ref.watch(chatRepositoryProvider).streamMessages(base.id).map(_bucket);
});

Map<DayKey, List<DayShare>> _bucket(ChatFeed feed) {
  final images =
      <({int index, DateTime at, UserId author, List<MediaRef> media})>[];
  var index = 0;
  for (final message in feed.messages) {
    final order = index++;
    if (message.isPending) continue;
    // Remove when chat video ships (December MVP) — memories should include clips.
    final media = <MediaRef>[
      for (final item in message.media)
        if (item.type == MediaType.image) item,
    ];
    if (media.isEmpty) continue;
    images.add((
      index: order,
      at: message.createdAt,
      author: message.userId,
      media: media,
    ));
  }
  images.sort((a, b) {
    final byTime = a.at.compareTo(b.at);
    if (byTime != 0) return byTime;
    return a.index.compareTo(b.index);
  });

  final grouped = <DayKey, List<DayShare>>{};
  for (final photo in images) {
    final shares = grouped.putIfAbsent(
      DayKey.fromLocal(photo.at),
      () => [],
    );
    if (shares.isNotEmpty && shares.last.author == photo.author) {
      final last = shares.removeLast();
      shares.add(
        DayShare(
          author: last.author,
          media: [...last.media, ...photo.media],
        ),
      );
    } else {
      shares.add(DayShare(author: photo.author, media: photo.media));
    }
  }
  return grouped;
}
