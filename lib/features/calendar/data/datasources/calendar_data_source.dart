import 'package:moonbase_skeleton/features/calendar/data/models/calendar_event_batch.dart';
import 'package:moonbase_skeleton/features/calendar/data/models/calendar_event_model.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_settings.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/event_input.dart';

/// Single data-source contract for the calendar (D-8 / U-4: no local/remote
/// split — Firestore's persistence layer *is* the local cache, surfaced via
/// `fromCache`). Methods throw; `CalendarRepositoryImpl` guards them.
abstract class CalendarDataSource {
  Stream<CalendarEventBatch> watchEvents({
    required String baseId,
    required DateTime fromUtc,
    required DateTime toExclusiveUtc,
  });

  Future<CalendarEventModel> createEvent({
    required String baseId,
    required String createdBy,
    required EventInput input,
  });

  Future<void> updateEvent({
    required String baseId,
    required String eventId,
    required EventInput input,
  });

  Future<void> deleteEvent({required String baseId, required String eventId});

  /// Missing doc ⇒ `CalendarSettings.defaults`.
  Future<CalendarSettings> getSettings({required String baseId});

  Future<void> setSettings({
    required String baseId,
    required CalendarSettings settings,
  });
}
