import 'package:flutter/material.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_event.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_window.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/viewmodels/calendar_home_vm.dart';

/// Date/time copy via `MaterialLocalizations` — no `intl` dependency (D-7).
/// All instants are converted to device-local before formatting (U-2).

String formatDayHeader(BuildContext context, DayKey day,
    {required bool isToday}) {
  final l = MaterialLocalizations.of(context);
  final full = l.formatFullDate(day.localMidnight);
  return isToday ? 'Today · $full' : full;
}

String formatEventTime(BuildContext context, CalendarEvent e) {
  if (e.allDay) return 'All day';
  final l = MaterialLocalizations.of(context);
  final start = l.formatTimeOfDay(TimeOfDay.fromDateTime(e.startAt.toLocal()));
  final end = e.endAt;
  if (end == null) return start;
  return '$start – ${l.formatTimeOfDay(TimeOfDay.fromDateTime(end.toLocal()))}';
}

String formatEventDate(BuildContext context, CalendarEvent e) =>
    MaterialLocalizations.of(context).formatMediumDate(e.startAt.toLocal());

String formatWindowLabel(CalendarWindow w) =>
    'Showing ${_days(w.pastDays)} back, ${_days(w.futureDays)} ahead';

String _days(int n) => n == 1 ? '1 day' : '$n days';
