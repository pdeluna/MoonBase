import 'package:flutter/material.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/calendar_span.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/viewmodels/calendar_home_vm.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/calendar_tokens.dart';

/// Seven days. Every column selects its day, including days with no events.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.days,
    required this.selected,
    required this.memoryDays,
    required this.onSelect,
  });

  static const stripKey = Key('calendar-week-strip');

  final List<CalendarGridDay> days;
  final DayKey selected;
  final Set<DayKey> memoryDays;
  final ValueChanged<DayKey> onSelect;

  static Key dayKey(DayKey day) => ValueKey<String>(
        'calendar-week-${day.year}-${day.month}-${day.day}',
      );

  static Key circleKey(DayKey day) => ValueKey<String>(
        'calendar-week-circle-${day.year}-${day.month}-${day.day}',
      );

  static Key eventDotKey(DayKey day) => ValueKey<String>(
        'calendar-week-event-${day.year}-${day.month}-${day.day}',
      );

  static Key memoryDotKey(DayKey day) => ValueKey<String>(
        'calendar-week-memory-${day.year}-${day.month}-${day.day}',
      );

  @override
  Widget build(BuildContext context) {
    final tokens = CalendarTokens.of(context);
    final l10n = MaterialLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        key: stripKey,
        color: tokens.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: tokens.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Row(
            children: [
              for (final day in days)
                Expanded(
                  child: _WeekDay(
                    day: day,
                    initial: l10n.narrowWeekdays[sundayBasedWeekday(day.day)],
                    selected: day.day == selected,
                    hasMemory: memoryDays.contains(day.day),
                    label: _label(l10n, day, memoryDays.contains(day.day)),
                    onTap: () => onSelect(day.day),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _label(MaterialLocalizations l10n, CalendarGridDay day, bool memory) {
  final date = l10n.formatFullDate(day.day.localMidnight);
  final notes = <String>[
    if (day.isToday) 'today',
    if (!day.isEmpty) 'events',
    if (memory) 'memories',
  ];
  if (notes.isEmpty) return date;
  return '$date, ${notes.join(', ')}';
}

class _WeekDay extends StatelessWidget {
  const _WeekDay({
    required this.day,
    required this.initial,
    required this.selected,
    required this.hasMemory,
    required this.label,
    required this.onTap,
  });

  final CalendarGridDay day;
  final String initial;
  final bool selected;
  final bool hasMemory;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = CalendarTokens.of(context);
    final isToday = day.isToday;
    final outlined = selected && !isToday;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: InkWell(
          key: WeekStrip.dayKey(day.day),
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Column(
              children: [
                Text(
                  initial,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isToday ? tokens.ink : tokens.secondary,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  key: WeekStrip.circleKey(day.day),
                  width: 30,
                  height: 30,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isToday ? CalendarTokens.accent : null,
                      border: outlined
                          ? Border.all(color: CalendarTokens.accent, width: 1.5)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '${day.day.day}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isToday ? FontWeight.w600 : FontWeight.w500,
                          color: isToday ? Colors.white : tokens.ink,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 5,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!day.isEmpty)
                        _Dot(
                          key: WeekStrip.eventDotKey(day.day),
                          color: CalendarTokens.accent,
                        ),
                      if (!day.isEmpty && hasMemory) const SizedBox(width: 3),
                      if (hasMemory)
                        _Dot(
                          key: WeekStrip.memoryDotKey(day.day),
                          color: CalendarTokens.memory,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 5,
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
