import 'package:flutter/material.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/calendar_span.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/viewmodels/calendar_home_vm.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/calendar_tokens.dart';

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
    required this.selected,
    required this.memoryDays,
    required this.inWindow,
    required this.onSelectDay,
  });

  static const gridKey = Key('calendar-grid');
  static const radius = 22.0;
  static const gap = 2.0;
  static const rowHeight = 64.0;

  final List<CalendarGridDay> days;
  final DayKey selected;
  final Set<DayKey> memoryDays;
  final bool Function(DayKey day) inWindow;
  final ValueChanged<DayKey> onSelectDay;

  static Key cellKey(DayKey day) =>
      ValueKey<String>('calendar-cell-${day.year}-${day.month}-${day.day}');

  static Key dotKey(DayKey day, int index) => ValueKey<String>(
        'calendar-dot-${day.year}-${day.month}-${day.day}-$index',
      );

  static Key moreKey(DayKey day) =>
      ValueKey<String>('calendar-more-${day.year}-${day.month}-${day.day}');

  static Key memoryDotKey(DayKey day) => ValueKey<String>(
        'calendar-memory-${day.year}-${day.month}-${day.day}',
      );

  @override
  Widget build(BuildContext context) {
    final tokens = CalendarTokens.of(context);
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
                      color: tokens.ink,
                    ),
                  ),
                ),
            ],
          ),
        ),
        _MonthRows(
          days: days,
          selected: selected,
          memoryDays: memoryDays,
          inWindow: inWindow,
          onSelectDay: onSelectDay,
        ),
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
  const _MonthRows({
    required this.days,
    required this.selected,
    required this.memoryDays,
    required this.inWindow,
    required this.onSelectDay,
  });

  final List<CalendarGridDay> days;
  final DayKey selected;
  final Set<DayKey> memoryDays;
  final bool Function(DayKey day) inWindow;
  final ValueChanged<DayKey> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final rowCount = days.length ~/ 7;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < rowCount; r++)
          _DayRow(
            days: days.sublist(r * 7, r * 7 + 7),
            selected: selected,
            memoryDays: memoryDays,
            inWindow: inWindow,
            onSelectDay: onSelectDay,
          ),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.days,
    required this.selected,
    required this.memoryDays,
    required this.inWindow,
    required this.onSelectDay,
  });

  final List<CalendarGridDay> days;
  final DayKey selected;
  final Set<DayKey> memoryDays;
  final bool Function(DayKey day) inWindow;
  final ValueChanged<DayKey> onSelectDay;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: CalendarGrid.rowHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final day in days)
            Expanded(
              child: CalendarDayCell(
                day: day,
                selected: day.day == selected,
                hasMemory: memoryDays.contains(day.day),
                onTap: inWindow(day.day) ? () => onSelectDay(day.day) : null,
              ),
            ),
        ],
      ),
    );
  }
}

class CalendarDayCell extends StatelessWidget {
  const CalendarDayCell({
    super.key,
    required this.day,
    required this.selected,
    required this.hasMemory,
    required this.onTap,
  });

  final CalendarGridDay day;
  final bool selected;
  final bool hasMemory;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = CalendarTokens.of(context);
    final fill = day.isToday ? CalendarTokens.accent : tokens.card;
    final numeralColor = day.isToday ? Colors.white : tokens.ink;
    final outlined = selected && !day.isToday;
    return Padding(
      key: CalendarGrid.cellKey(day.day),
      padding: const EdgeInsets.all(CalendarGrid.gap),
      child: Semantics(
        button: onTap != null,
        selected: selected,
        label: _label(day),
        child: ExcludeSemantics(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(CalendarGrid.radius),
              border: outlined
                  ? Border.all(color: CalendarTokens.accent, width: 1.5)
                  : null,
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
                      if (!day.isEmpty || hasMemory) ...[
                        const SizedBox(height: 4),
                        _MonthDots(
                          day: day,
                          onToday: day.isToday,
                          hasMemory: hasMemory,
                        ),
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
  const _MonthDots({
    required this.day,
    required this.onToday,
    required this.hasMemory,
  });

  final CalendarGridDay day;
  final bool onToday;
  final bool hasMemory;

  @override
  Widget build(BuildContext context) {
    final tokens = CalendarTokens.of(context);
    final count = day.events.length;
    final overflow = count > 3;
    final dotCount = overflow ? 2 : count;
    final mark = onToday ? Colors.white : CalendarTokens.accent;
    final more = onToday ? Colors.white : tokens.ink;
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
              decoration: BoxDecoration(color: mark, shape: BoxShape.circle),
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
              color: more,
              height: 1.0,
            ),
          ),
        ],
        if (hasMemory) ...[
          if (dotCount > 0 || overflow) const SizedBox(width: 3),
          SizedBox(
            key: CalendarGrid.memoryDotKey(day.day),
            width: 6,
            height: 6,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: CalendarTokens.memory,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
