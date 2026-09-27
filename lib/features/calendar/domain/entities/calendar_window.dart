import 'package:moonbase_skeleton/core/validators.dart';

/// Half-open instant range `[from, toExclusive)` — both UTC.
class CalendarDateRange {
  const CalendarDateRange({required this.from, required this.toExclusive});

  final DateTime from;
  final DateTime toExclusive;

  bool contains(DateTime instant) {
    final t = instant.toUtc();
    return !t.isBefore(from) && t.isBefore(toExclusive);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalendarDateRange &&
          other.from == from &&
          other.toExclusive == toExclusive);

  @override
  int get hashCode => Object.hash(from, toExclusive);

  @override
  String toString() => 'CalendarDateRange($from → $toExclusive)';
}

/// Rolling visible window around today: [pastDays] back, [futureDays] ahead.
///
/// Days are whole **device-local** calendar days; `today` is injected into
/// [resolve] so tests never depend on the wall clock. Both counts are clamped
/// to `0..kCalendarWindowMaxDays` (mirrored by rules `isValidWindowDays`).
class CalendarWindow {
  const CalendarWindow({required this.pastDays, required this.futureDays});

  /// The accepted MVP default (D-2). Referenced by `CalendarSettings.defaults`.
  static const defaults = CalendarWindow(pastDays: 7, futureDays: 30);

  final int pastDays;
  final int futureDays;

  CalendarWindow clamp() => CalendarWindow(
        pastDays: pastDays.clamp(0, kCalendarWindowMaxDays),
        futureDays: futureDays.clamp(0, kCalendarWindowMaxDays),
      );

  bool get isValid =>
      pastDays >= 0 &&
      pastDays <= kCalendarWindowMaxDays &&
      futureDays >= 0 &&
      futureDays <= kCalendarWindowMaxDays;

  /// Local midnight of `today - pastDays` up to (excluding) local midnight of
  /// `today + futureDays + 1`, converted to UTC for storage-side comparison.
  CalendarDateRange resolve(DateTime today) {
    final local = today.toLocal();
    final startOfToday = DateTime(local.year, local.month, local.day);
    final from = DateTime(
      startOfToday.year,
      startOfToday.month,
      startOfToday.day - pastDays,
    );
    final toExclusive = DateTime(
      startOfToday.year,
      startOfToday.month,
      startOfToday.day + futureDays + 1,
    );
    return CalendarDateRange(
      from: from.toUtc(),
      toExclusive: toExclusive.toUtc(),
    );
  }

  /// Number of local calendar days the window spans (today included).
  int get totalDays => pastDays + futureDays + 1;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalendarWindow &&
          other.pastDays == pastDays &&
          other.futureDays == futureDays);

  @override
  int get hashCode => Object.hash(pastDays, futureDays);

  @override
  String toString() => 'CalendarWindow(past: $pastDays, future: $futureDays)';
}
