import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/auth/domain/entities/user.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_event.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_freshness.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_permissions.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_settings.dart';

/// Home-tab body state derived from `basesListProvider` +
/// `effectiveSelectedBaseProvider` (bug B-e: never show the "create your
/// first base" prompt while bases are loading or unreachable).
enum CalendarBasesState {
  /// Bases list still loading — skeleton.
  loading,

  /// Bases list errored (network / timeout) — plain-language copy + Retry.
  unreachable,

  /// Bases loaded but none is selected (user has none, or none picked).
  empty,

  /// A base is selected — agenda.
  ready,
}

/// Local calendar day (device time zone) used for grouping.
class DayKey implements Comparable<DayKey> {
  const DayKey(this.year, this.month, this.day);

  factory DayKey.fromLocal(DateTime instant) {
    final l = instant.toLocal();
    return DayKey(l.year, l.month, l.day);
  }

  final int year;
  final int month;
  final int day;

  DateTime get localMidnight => DateTime(year, month, day);

  DayKey addDays(int n) => DayKey.fromLocal(DateTime(year, month, day + n));

  @override
  int compareTo(DayKey other) => localMidnight.compareTo(other.localMidnight);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DayKey &&
          other.year == year &&
          other.month == month &&
          other.day == day);

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => 'DayKey($year-$month-$day)';
}

class DaySection {
  const DaySection({
    required this.day,
    required this.events,
    required this.isToday,
  });

  final DayKey day;

  /// Sorted by `startAt` then `createdAt`.
  final List<CalendarEvent> events;
  final bool isToday;

  bool get isEmpty => events.isEmpty;
}

/// Immutable props only — no Riverpod, no widgets.
class CalendarHomeVM {
  const CalendarHomeVM({
    required this.basesState,
    required this.hasBases,
    required this.selectedBase,
    required this.currentUser,
    required this.isOwner,
    required this.settings,
    required this.canAddEvent,
    required this.isFeedLoading,
    required this.feedError,
    required this.freshness,
    required this.sections,
    required this.todayKey,
    required this.isTruncated,
    required this.settingsUnavailable,
  });

  const CalendarHomeVM.noBase({
    required this.basesState,
    required this.hasBases,
    required this.currentUser,
    required this.todayKey,
  })  : selectedBase = null,
        isOwner = false,
        settings = CalendarSettings.defaults,
        canAddEvent = false,
        isFeedLoading = false,
        feedError = null,
        freshness = null,
        sections = const [],
        isTruncated = false,
        settingsUnavailable = false;

  final CalendarBasesState basesState;

  /// True when the bases list loaded non-empty (drives "pick a base" vs
  /// "create your first base" copy in the empty state).
  final bool hasBases;
  final Base? selectedBase;
  final User? currentUser;
  final bool isOwner;
  final CalendarSettings settings;

  /// FAB visibility only — `CreateEvent` re-checks the same policy object.
  final bool canAddEvent;
  final bool isFeedLoading;
  final Object? feedError;

  /// Null until the feed has emitted.
  final CalendarFreshness? freshness;

  /// One section per local day in the window, in ascending order. Empty when
  /// the feed has not emitted or the window holds zero events.
  final List<DaySection> sections;
  final DayKey todayKey;
  final bool isTruncated;

  /// The settings read failed and defaults are in effect.
  final bool settingsUnavailable;

  bool get isReady => basesState == CalendarBasesState.ready;
  bool get hasEvents => sections.any((s) => s.events.isNotEmpty);
  int get eventCount => sections.fold<int>(0, (n, s) => n + s.events.length);

  /// Author-or-owner affordance (same predicate the use cases enforce).
  bool canModify(CalendarEvent event) {
    final base = selectedBase;
    final user = currentUser;
    if (base == null || user == null) return false;
    return canModifyEvent(event: event, user: user.id, base: base);
  }

  UserId? get currentUserId => currentUser?.id;
}
