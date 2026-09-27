import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_feed.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_window.dart';
import 'package:moonbase_skeleton/features/calendar/domain/repositories/calendar_repository.dart';

/// Live feed for one base inside a resolved window. A future
/// `ReminderScheduler` consumes this same stream without touching the data
/// source (notifications data architecture, FIRESTORE_UPDATE_TRIGGERS #19).
class WatchEvents {
  const WatchEvents(this.repo);

  final CalendarRepository repo;

  Stream<CalendarFeed> call({
    required BaseId baseId,
    required CalendarDateRange range,
  }) =>
      repo.watchEvents(baseId: baseId, range: range);
}
