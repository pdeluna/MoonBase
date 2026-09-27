import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/features/auth/presentation/providers/auth_providers.dart';
import 'package:moonbase_skeleton/features/bases/presentation/providers/sidebar_providers.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_event.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_feed.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_window.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/controllers/calendar_controller.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/viewmodels/calendar_home_vm.dart';

/// Wall clock for "today"; overridable in tests.
final calendarClockProvider =
    Provider<DateTime Function()>((ref) => DateTime.now);

/// Derived, immutable view of the Home tab.
final calendarHomeVmProvider = Provider<CalendarHomeVM>((ref) {
  final basesAsync = ref.watch(basesListProvider);
  final selectedBase = ref.watch(effectiveSelectedBaseProvider);
  final currentUser = ref.watch(currentUserProvider).valueOrNull;
  final calendarState = ref.watch(calendarControllerProvider);
  final now = ref.watch(calendarClockProvider)();
  final todayKey = DayKey.fromLocal(now);

  final hasBases = basesAsync.valueOrNull?.isNotEmpty ?? false;

  final basesState = basesAsync.when(
    loading: () => CalendarBasesState.loading,
    error: (_, __) => CalendarBasesState.unreachable,
    data: (_) => selectedBase == null
        ? CalendarBasesState.empty
        : CalendarBasesState.ready,
  );

  if (basesState != CalendarBasesState.ready || selectedBase == null) {
    return CalendarHomeVM.noBase(
      basesState: basesState,
      hasBases: hasBases,
      currentUser: currentUser,
      todayKey: todayKey,
    );
  }

  final isOwner =
      currentUser != null && selectedBase.ownerUserId == currentUser.id;
  final settings = calendarState.settings;
  final canAdd = currentUser != null &&
      settings.canCreate(user: currentUser.id, base: selectedBase);

  // The controller may still hold the previous base's feed for one frame
  // after a switch; treat a mismatched baseId as loading.
  final feedForThisBase = calendarState.baseId == selectedBase.id.value;
  final feed = feedForThisBase ? calendarState.feed : null;

  return CalendarHomeVM(
    basesState: basesState,
    hasBases: hasBases,
    selectedBase: selectedBase,
    currentUser: currentUser,
    isOwner: isOwner,
    settings: settings,
    canAddEvent: canAdd,
    isFeedLoading: feed == null || feed.isLoading,
    feedError: feed?.error,
    freshness: feed?.valueOrNull?.freshness,
    sections: feed?.valueOrNull == null
        ? const []
        : groupByDay(feed!.valueOrNull!, settings.window, now),
    todayKey: todayKey,
    isTruncated: feed?.valueOrNull?.isTruncated ?? false,
    settingsUnavailable: calendarState.settingsFailure != null,
  );
});

/// One [DaySection] per local day of [window] around [today], ascending.
/// Events fall into the section of their **device-local** start date.
List<DaySection> groupByDay(
  CalendarFeed feed,
  CalendarWindow window,
  DateTime today,
) {
  final todayKey = DayKey.fromLocal(today);
  final byDay = <DayKey, List<CalendarEvent>>{};
  for (final e in feed.events) {
    (byDay[DayKey.fromLocal(e.startAt)] ??= []).add(e);
  }
  final first = todayKey.addDays(-window.pastDays);
  return List<DaySection>.generate(window.totalDays, (i) {
    final day = first.addDays(i);
    return DaySection(
      day: day,
      events: List.unmodifiable(byDay[day] ?? const <CalendarEvent>[]),
      isToday: day == todayKey,
    );
  });
}
