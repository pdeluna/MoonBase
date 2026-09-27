import 'package:moonbase_skeleton/features/calendar/data/models/calendar_event_model.dart';

/// One snapshot of events plus whether it came from cache.
///
/// Firebase `SnapshotMetadata` stays in the Firestore data source.
/// [fromCache] is `snap.metadata.isFromCache` alone — do not AND
/// `hasPendingWrites` (same rule as `ChatMessageBatch`).
class CalendarEventBatch {
  const CalendarEventBatch({required this.events, required this.fromCache});

  final List<CalendarEventModel> events;
  final bool fromCache;
}
