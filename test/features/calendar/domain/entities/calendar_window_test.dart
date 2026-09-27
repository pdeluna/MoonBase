import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/core/validators.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_settings.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_window.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/event_creation_policy.dart';

import '../../../../test_utils/fakes_calendar.dart';

void main() {
  group('CalendarWindow.resolve (injected today)', () {
    test('defaults 7/30 span local midnight -7d to midnight +31d', () {
      final r = CalendarWindow.defaults.resolve(kToday);
      expect(r.from, DateTime(2026, 9, 20).toUtc());
      expect(r.toExclusive, DateTime(2026, 10, 28).toUtc());
      expect(CalendarWindow.defaults.totalDays, 38);
    });

    test('0/0 window is exactly today', () {
      final r =
          const CalendarWindow(pastDays: 0, futureDays: 0).resolve(kToday);
      expect(r.contains(DateTime(2026, 9, 27, 0, 0).toUtc()), isTrue);
      expect(r.contains(DateTime(2026, 9, 27, 23, 59).toUtc()), isTrue);
      expect(r.contains(DateTime(2026, 9, 28).toUtc()), isFalse);
      expect(r.contains(DateTime(2026, 9, 26, 23, 59).toUtc()), isFalse);
    });

    test('range is half-open and compares in UTC', () {
      final r =
          const CalendarWindow(pastDays: 1, futureDays: 1).resolve(kToday);
      expect(r.contains(r.from), isTrue);
      expect(r.contains(r.toExclusive), isFalse);
      expect(r.from.isUtc, isTrue);
      expect(r.toExclusive.isUtc, isTrue);
    });

    test('today given as UTC resolves the same local range', () {
      final a = CalendarWindow.defaults.resolve(kToday);
      final b = CalendarWindow.defaults.resolve(kToday.toUtc());
      expect(a, b);
    });
  });

  group('CalendarWindow.clamp / isValid', () {
    test('clamps to 0..kCalendarWindowMaxDays', () {
      const w = CalendarWindow(pastDays: -3, futureDays: 9999);
      expect(w.isValid, isFalse);
      expect(
          w.clamp(),
          const CalendarWindow(
              pastDays: 0, futureDays: kCalendarWindowMaxDays));
      expect(w.clamp().isValid, isTrue);
    });

    test('defaults are valid and equal the single settings default', () {
      expect(CalendarWindow.defaults.isValid, isTrue);
      expect(CalendarSettings.defaults.window, CalendarWindow.defaults);
      expect(CalendarSettings.defaults.eventCreation,
          EventCreationPolicy.allMembers);
    });
  });

  group('CalendarSettings.canCreate', () {
    test('allMembers: everyone may create', () {
      const s = CalendarSettings.defaults;
      expect(s.canCreate(user: kMember, base: kBase), isTrue);
      expect(s.canCreate(user: kOwner, base: kBase), isTrue);
    });

    test('ownerOnly: only the base owner may create', () {
      final s = CalendarSettings.defaults
          .copyWith(eventCreation: EventCreationPolicy.ownerOnly);
      expect(s.canCreate(user: kMember, base: kBase), isFalse);
      expect(s.canCreate(user: kOwner, base: kBase), isTrue);
    });
  });
}
