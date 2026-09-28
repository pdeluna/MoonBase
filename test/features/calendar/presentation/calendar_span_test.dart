import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/calendar_span.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/viewmodels/calendar_home_vm.dart';

import '../../../test_utils/fakes_calendar.dart';

void main() {
  const sunday = 0;
  const monday = 1;
  final today = DayKey.fromLocal(kToday);

  DaySection section(DayKey day, {String? title}) => DaySection(
    day: day,
    events: [if (title != null) eventBy(kOwner, title: title)],
    isToday: day == today,
  );

  test('Sunday 27 Sep 2026 is the fixture', () {
    expect(today, const DayKey(2026, 9, 27));
    expect(sundayBasedWeekday(today), 0);
    expect(daysAfterWeekStart(const DayKey(2026, 9, 1), sunday), 2);
    expect(daysAfterWeekStart(const DayKey(2026, 9, 1), monday), 1);
  });

  test('week is the locale week that contains today', () {
    final sundayFirst = gridDays(
      span: CalendarDrawSpan.week,
      sections: [section(today, title: 'Dinner')],
      today: today,
      firstDayOfWeekIndex: sunday,
    );
    expect(sundayFirst.map((d) => d.day).toList(), [
      const DayKey(2026, 9, 27),
      const DayKey(2026, 9, 28),
      const DayKey(2026, 9, 29),
      const DayKey(2026, 9, 30),
      const DayKey(2026, 10, 1),
      const DayKey(2026, 10, 2),
      const DayKey(2026, 10, 3),
    ]);
    expect(sundayFirst.first.events.single.title, 'Dinner');
    expect(sundayFirst[1].isEmpty, isTrue);

    final mondayFirst = weekKeys(today, monday);
    expect(mondayFirst.first, const DayKey(2026, 9, 21));
    expect(mondayFirst.last, const DayKey(2026, 9, 27));

    const mondayToday = DayKey(2026, 9, 28);
    expect(weekKeys(mondayToday, sunday).first, const DayKey(2026, 9, 27));
    expect(weekKeys(mondayToday, monday).first, mondayToday);
    expect(weekKeys(mondayToday, monday).last, const DayKey(2026, 10, 4));
  });

  test('month grid is rectangular and days outside sections are empty', () {
    final days = gridDays(
      span: CalendarDrawSpan.month,
      sections: [section(today, title: 'Dinner')],
      today: today,
      firstDayOfWeekIndex: sunday,
    );
    expect(days, hasLength(35));
    expect(days.first.day, const DayKey(2026, 8, 30));
    expect(days.last.day, const DayKey(2026, 10, 3));

    final outside = days.firstWhere((d) => d.day == const DayKey(2026, 9, 1));
    final loaded = days.firstWhere((d) => d.day == today);
    expect(outside.isEmpty, isTrue);
    expect(outside.isToday, isFalse);
    expect(loaded.isToday, isTrue);
    expect(loaded.events.single.title, 'Dinner');
  });

  test('header names the week span, or today\'s month', () {
    expect(
      headerMonths(
        span: CalendarDrawSpan.week,
        today: today,
        firstDayOfWeekIndex: sunday,
      ),
      [DateTime(2026, 9), DateTime(2026, 10)],
    );
    expect(
      headerMonths(
        span: CalendarDrawSpan.month,
        today: today,
        firstDayOfWeekIndex: sunday,
      ),
      [DateTime(2026, 9)],
    );
  });
}
