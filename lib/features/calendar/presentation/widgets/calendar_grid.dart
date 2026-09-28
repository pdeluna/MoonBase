import 'package:flutter/material.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_window.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/calendar_span.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/viewmodels/calendar_home_vm.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/lunar_candy.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/window_label.dart';

/// Month name, the week/month control, and the existing window caption.
class CalendarGridHeader extends StatelessWidget {
  const CalendarGridHeader({
    super.key,
    required this.span,
    required this.today,
    required this.window,
    required this.isOwner,
    required this.onToggleSpan,
    required this.onOpenSettings,
  });

  static const spanKey = Key('calendar-span-toggle');

  final CalendarDrawSpan span;
  final DayKey today;
  final CalendarWindow window;
  final bool isOwner;
  final VoidCallback onToggleSpan;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final candy = LunarCandy.of(context);
    final l10n = MaterialLocalizations.of(context);
    final title = formatGridHeader(
      l10n,
      span: span,
      today: today,
      firstDayOfWeekIndex: l10n.firstDayOfWeekIndex,
    );
    final expanding = span == CalendarDrawSpan.week;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: candy.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                key: spanKey,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: LunarCandy.accent,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                onPressed: onToggleSpan,
                child: Text(expanding ? 'Month' : 'Week'),
              ),
            ],
          ),
        ),
        WindowLabel(
          window: window,
          isOwner: isOwner,
          onOpenSettings: onOpenSettings,
        ),
      ],
    );
  }
}

/// Week row or month grid. Draws [days] only — it does not watch providers.
class CalendarGrid extends StatelessWidget {
  const CalendarGrid({
    super.key,
    required this.span,
    required this.days,
    required this.onDayTap,
  });

  static const gridKey = Key('calendar-grid');
  static const weekCellHeight = 104.0;
  static const radius = 22.0;
  static const gap = 2.0;

  final CalendarDrawSpan span;
  final List<CalendarGridDay> days;
  final ValueChanged<CalendarGridDay> onDayTap;

  static Key cellKey(DayKey day) =>
      ValueKey<String>('calendar-cell-${day.year}-${day.month}-${day.day}');

  static Key dotKey(DayKey day, int index) => ValueKey<String>(
    'calendar-dot-${day.year}-${day.month}-${day.day}-$index',
  );

  static Key moreKey(DayKey day) =>
      ValueKey<String>('calendar-more-${day.year}-${day.month}-${day.day}');

  @override
  Widget build(BuildContext context) {
    final candy = LunarCandy.of(context);
    final l10n = MaterialLocalizations.of(context);
    final labels = _weekdayLabels(l10n);
    final week = span == CalendarDrawSpan.week;
    return Column(
      key: gridKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
          child: Row(
            children: [
              for (final label in labels)
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: candy.ink,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (week)
          SizedBox(
            height: weekCellHeight,
            child: _DayRow(days: days, span: span, onDayTap: onDayTap),
          )
        else
          Expanded(child: _MonthRows(days: days, onDayTap: onDayTap)),
        if (week) const Spacer(),
      ],
    );
  }
}

List<String> _weekdayLabels(MaterialLocalizations l10n) {
  final start = l10n.firstDayOfWeekIndex;
  final names = l10n.narrowWeekdays;
  return [for (var i = 0; i < 7; i++) names[(start + i) % 7]];
}

String formatGridHeader(
  MaterialLocalizations l10n, {
  required CalendarDrawSpan span,
  required DayKey today,
  required int firstDayOfWeekIndex,
}) {
  final months = headerMonths(
    span: span,
    today: today,
    firstDayOfWeekIndex: firstDayOfWeekIndex,
  );
  return months.map(l10n.formatMonthYear).join(' – ');
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.days,
    required this.span,
    required this.onDayTap,
  });

  final List<CalendarGridDay> days;
  final CalendarDrawSpan span;
  final ValueChanged<CalendarGridDay> onDayTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final day in days)
          Expanded(
            child: CalendarDayCell(
              day: day,
              showChips: span == CalendarDrawSpan.week,
              onTap: day.isEmpty ? null : () => onDayTap(day),
            ),
          ),
      ],
    );
  }
}

class _MonthRows extends StatelessWidget {
  const _MonthRows({required this.days, required this.onDayTap});

  final List<CalendarGridDay> days;
  final ValueChanged<CalendarGridDay> onDayTap;

  @override
  Widget build(BuildContext context) {
    final rowCount = days.length ~/ 7;
    return Column(
      children: [
        for (var r = 0; r < rowCount; r++)
          Expanded(
            child: _DayRow(
              days: days.sublist(r * 7, r * 7 + 7),
              span: CalendarDrawSpan.month,
              onDayTap: onDayTap,
            ),
          ),
      ],
    );
  }
}

class CalendarDayCell extends StatelessWidget {
  const CalendarDayCell({
    super.key,
    required this.day,
    required this.showChips,
    required this.onTap,
  });

  final CalendarGridDay day;
  final bool showChips;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final candy = LunarCandy.of(context);
    final fill = day.isToday ? LunarCandy.today : candy.cell;
    final numeralColor = day.isToday ? candy.todayInk : candy.ink;
    return Padding(
      key: CalendarGrid.cellKey(day.day),
      padding: const EdgeInsets.all(CalendarGrid.gap),
      child: Semantics(
        button: onTap != null,
        label: _label(day),
        child: ExcludeSemantics(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(CalendarGrid.radius),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(CalendarGrid.radius),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 6,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${day.day.day}',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w900,
                          fontSize: showChips ? 22 : 16,
                          color: numeralColor,
                          height: 1.1,
                        ),
                      ),
                      if (!day.isEmpty) ...[
                        const SizedBox(height: 4),
                        if (showChips)
                          _WeekChips(day: day)
                        else
                          _MonthDots(day: day, candy: candy),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _label(CalendarGridDay day) {
  final n = '${day.day.day}';
  if (day.isEmpty) return n;
  if (day.events.length == 1) return '$n, ${day.events.first.title}';
  return '$n, ${day.events.length} events';
}

class _WeekChips extends StatelessWidget {
  const _WeekChips({required this.day});

  final CalendarGridDay day;

  @override
  Widget build(BuildContext context) {
    final extra = day.events.length - 1;
    return Column(
      children: [
        _Chip(
          text: day.events.first.title,
          background: LunarCandy.accent,
          foreground: Colors.white,
        ),
        if (extra > 0) ...[
          const SizedBox(height: 2),
          _Chip(
            key: CalendarGrid.moreKey(day.day),
            text: '+$extra',
            background: LunarCandy.pop,
            foreground: LunarCandy.inkLight,
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w500,
            fontSize: 10,
            color: foreground,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

class _MonthDots extends StatelessWidget {
  const _MonthDots({required this.day, required this.candy});

  final CalendarGridDay day;
  final LunarCandy candy;

  @override
  Widget build(BuildContext context) {
    final count = day.events.length;
    final overflow = count > 3;
    final dotCount = overflow ? 2 : count;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < dotCount; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          SizedBox(
            key: CalendarGrid.dotKey(day.day, i),
            width: 6,
            height: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: candy.dotColor(i),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
        if (overflow) ...[
          const SizedBox(width: 3),
          Text(
            '+',
            key: CalendarGrid.moreKey(day.day),
            style: TextStyle(
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w500,
              fontSize: 11,
              color: day.isToday ? candy.todayInk : candy.ink,
              height: 1,
            ),
          ),
        ],
      ],
    );
  }
}
