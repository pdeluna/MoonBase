import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/features/bases/presentation/providers/sidebar_providers.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/viewmodels/calendar_home_vm.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/chat_feed.dart';
import 'package:moonbase_skeleton/features/chat/presentation/providers/chat_providers.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_type.dart';

/// Chat images for the selected base, one list per local day, newest first.
final chatMemoriesProvider = StreamProvider<Map<DayKey, List<MediaRef>>>((ref) {
  final base = ref.watch(effectiveSelectedBaseProvider);
  if (base == null) {
    return Stream<Map<DayKey, List<MediaRef>>>.value(const {});
  }
  return ref.watch(chatRepositoryProvider).streamMessages(base.id).map(_bucket);
});

Map<DayKey, List<MediaRef>> _bucket(ChatFeed feed) {
  final grouped =
      <DayKey, List<({int index, DateTime at, List<MediaRef> images})>>{};
  var index = 0;
  for (final message in feed.messages) {
    final order = index++;
    if (message.isPending) continue;
    // Remove when chat video ships (December MVP) — memories should include clips.
    final images = <MediaRef>[
      for (final item in message.media)
        if (item.type == MediaType.image) item,
    ];
    if (images.isEmpty) continue;
    grouped
        .putIfAbsent(DayKey.fromLocal(message.createdAt), () => [])
        .add((index: order, at: message.createdAt, images: images));
  }
  return {
    for (final entry in grouped.entries)
      entry.key: [
        for (final photo in (entry.value
          ..sort((a, b) {
            final byTime = b.at.compareTo(a.at);
            if (byTime != 0) return byTime;
            return a.index.compareTo(b.index);
          })))
          ...photo.images,
      ],
  };
}
