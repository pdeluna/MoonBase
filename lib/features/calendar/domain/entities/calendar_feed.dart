import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_event.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_freshness.dart';

/// Client safety cap on the window query. The data source applies
/// `limit(kCalendarFeedLimit)`; the UI surfaces a banner when a feed reaches
/// it instead of paginating (FIRESTORE_UPDATE_TRIGGERS #21).
const int kCalendarFeedLimit = 200;

/// Events inside the visible window plus whether that list is cached or live.
///
/// Do not flatten to `List<CalendarEvent>` before the UI, or freshness has
/// nowhere to live (same posture as `ChatFeed`).
class CalendarFeed {
  const CalendarFeed({required this.events, required this.freshness});

  /// Sorted by `startAt`, then `createdAt`.
  final List<CalendarEvent> events;
  final CalendarFreshness freshness;

  /// True when the query hit [kCalendarFeedLimit] — there may be more events
  /// in the window than shown.
  bool get isTruncated => events.length >= kCalendarFeedLimit;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CalendarFeed &&
        other.freshness == freshness &&
        _listEquals(other.events, events);
  }

  @override
  int get hashCode => Object.hash(freshness, Object.hashAll(events));
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
