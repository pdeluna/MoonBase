import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_event.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/viewmodels/calendar_home_vm.dart';

/// How much of the calendar the Home grid draws. Ephemeral view state —
/// not saved on calendar settings and not a second query.
enum CalendarDrawSpan { week, month }

/// One cell. Days the grid draws that are missing from [DaySection]s (outside
/// the saved window) carry an empty event list, so they paint like a loaded
/// day that has no events.
class CalendarGridDay {
  const CalendarGridDay({
    required this.day,
    required this.events,
    required this.isToday,
  });

  final DayKey day;
  final List<CalendarEvent> events;
  final bool isToday;

  bool get isEmpty => events.isEmpty;
}

/// `DateTime.weekday` is Monday=1 … Sunday=7. Material localizations count
/// Sunday as 0, matching `firstDayOfWeekIndex`.
int sundayBasedWeekday(DayKey day) => day.localMidnight.weekday % 7;

/// Days from the locale week start back to [day] (0 when [day] is the start).
int daysAfterWeekStart(DayKey day, int firstDayOfWeekIndex) =>
    (sundayBasedWeekday(day) - firstDayOfWeekIndex + 7) % 7;

/// Cells for [span] around [today], in reading order.
///
/// Week is the seven local days of the week that contains [today]. Month is
/// every date in that month plus the leading and trailing days that complete
/// the first and last rows. [firstDayOfWeekIndex] is 0 = Sunday.
List<CalendarGridDay> gridDays({
  required CalendarDrawSpan span,
  required List<DaySection> sections,
  required DayKey today,
  required int firstDayOfWeekIndex,
}) {
  final byDay = <DayKey, DaySection>{
    for (final section in sections) section.day: section,
  };
  final keys =
      span == CalendarDrawSpan.week
          ? weekKeys(today, firstDayOfWeekIndex)
          : monthKeys(today, firstDayOfWeekIndex);
  return [
    for (final day in keys)
      CalendarGridDay(
        day: day,
        events: List<CalendarEvent>.unmodifiable(
          byDay[day]?.events ?? const <CalendarEvent>[],
        ),
        isToday: day == today,
      ),
  ];
}

/// Seven local days of the week that contains [today].
List<DayKey> weekKeys(DayKey today, int firstDayOfWeekIndex) {
  final start = today.addDays(-daysAfterWeekStart(today, firstDayOfWeekIndex));
  return List<DayKey>.generate(7, start.addDays);
}

/// Rectangular month grid containing [today], including leading/trailing days.
List<DayKey> monthKeys(DayKey today, int firstDayOfWeekIndex) {
  final first = DayKey(today.year, today.month, 1);
  final leading = daysAfterWeekStart(first, firstDayOfWeekIndex);
  final start = first.addDays(-leading);
  final daysInMonth = DateTime(today.year, today.month + 1, 0).day;
  final rows = ((leading + daysInMonth) / 7).ceil();
  return List<DayKey>.generate(rows * 7, start.addDays);
}

/// Months named in the grid header, in order. Week may span two. Month mode
/// names today's calendar month only (leading/trailing days stay unlabeled).
List<DateTime> headerMonths({
  required CalendarDrawSpan span,
  required DayKey today,
  required int firstDayOfWeekIndex,
}) {
  if (span == CalendarDrawSpan.month) {
    return [DateTime(today.year, today.month)];
  }
  final seen = <String>{};
  final months = <DateTime>[];
  for (final day in weekKeys(today, firstDayOfWeekIndex)) {
    if (seen.add('${day.year}-${day.month}')) {
      months.add(DateTime(day.year, day.month));
    }
  }
  return months;
}
