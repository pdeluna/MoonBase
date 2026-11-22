import 'package:flutter/material.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/calendar_span.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/viewmodels/calendar_home_vm.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/calendar_tokens.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/lunar_candy.dart';

/// Month name (month span only) and the week/month control.
class CalendarGridHeader extends StatelessWidget {
  const CalendarGridHeader({
    super.key,
    required this.span,
    required this.today,
    required this.onToggleSpan,
  });

  static const spanKey = Key('calendar-span-toggle');

  final CalendarDrawSpan span;
  final DayKey today;
  final VoidCallback onToggleSpan;

  @override
  Widget build(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    final expanding = span == CalendarDrawSpan.week;
    final title = expanding
        ? null
        : formatGridHeader(
            l10n,
            span: span,
            today: today,
            firstDayOfWeekIndex: l10n.firstDayOfWeekIndex,
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
      child: Row(
        children: [
          if (title != null)
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: CalendarTokens.of(context).ink,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )
          else
            const Spacer(),
          TextButton(
            key: spanKey,
            style: TextButton.styleFrom(
              foregroundColor: CalendarTokens.accent,
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            onPressed: onToggleSpan,
            child: Text(expanding ? 'Month' : 'Week'),
          ),
        ],
      ),
    );
  }
}

/// Month grid. Draws [days] only — it does not watch providers.
class CalendarGrid extends StatelessWidget {
  const CalendarGrid({
    super.key,
    required this.days,
    required this.onDayTap,
  });

  static const gridKey = Key('calendar-grid');
  static const radius = 22.0;
  static const gap = 2.0;

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
    final labels = _weekdayLabels(MaterialLocalizations.of(context));
    return Column(
      key: gridKey,
      mainAxisSize: MainAxisSize.min,
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
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: candy.ink,
                    ),
                  ),
                ),
            ],
          ),
        ),
        _MonthRows(days: days, onDayTap: onDayTap),
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

class _MonthRows extends StatelessWidget {
  const _MonthRows({required this.days, required this.onDayTap});

  final List<CalendarGridDay> days;
  final ValueChanged<CalendarGridDay> onDayTap;

  @override
  Widget build(BuildContext context) {
    final rowCount = days.length ~/ 7;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < rowCount; r++)
          _DayRow(
            days: days.sublist(r * 7, r * 7 + 7),
            onDayTap: onDayTap,
          ),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.days, required this.onDayTap});

  final List<CalendarGridDay> days;
  final ValueChanged<CalendarGridDay> onDayTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final day in days)
          Expanded(
            child: CalendarDayCell(
              day: day,
              onTap: day.isEmpty ? null : () => onDayTap(day),
            ),
          ),
      ],
    );
  }
}

class CalendarDayCell extends StatelessWidget {
  const CalendarDayCell({super.key, required this.day, required this.onTap});

  final CalendarGridDay day;
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
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: numeralColor,
                          height: 1.1,
                        ),
                      ),
                      if (!day.isEmpty) ...[
                        const SizedBox(height: 4),
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
