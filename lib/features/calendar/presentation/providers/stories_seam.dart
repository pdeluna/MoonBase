import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/viewmodels/calendar_home_vm.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';

/// One author in the stories row. [opened] draws the bubble without a ring.
@immutable
class StoriesHeadingAuthor {
  const StoriesHeadingAuthor({required this.userId, required this.opened});

  final UserId userId;
  final bool opened;
}

/// What the Home stories row and the shared-today grid draw.
///
/// [authors] is newest first. [tiles] is today's shared media and can be
/// empty while [authors] is not.
@immutable
class StoriesHeadingData {
  const StoriesHeadingData({
    this.authors = const [],
    this.tiles = const [],
    this.keptUntil,
  });

  static const empty = StoriesHeadingData();

  final List<StoriesHeadingAuthor> authors;
  final List<MediaRef> tiles;

  /// When today's stories move onto the calendar, shown as a local time.
  final DateTime? keptUntil;
}

/// Home stories. Retry is `ref.invalidate(storiesHeadingProvider)`.
final storiesHeadingProvider = Provider<AsyncValue<StoriesHeadingData>>(
  (ref) => const AsyncValue.data(StoriesHeadingData.empty),
);

/// Local days with a memory dot. Days the strip is not drawing are ignored.
final memoryDaysProvider = Provider<Set<DayKey>>((ref) => const <DayKey>{});

/// Date-heading "+". Null until story capture is wired, which hides the button.
final openStoryCaptureProvider = Provider<void Function(BuildContext)?>(
  (ref) => null,
);
