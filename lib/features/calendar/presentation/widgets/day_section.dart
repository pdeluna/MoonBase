import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/features/auth/presentation/providers/member_presentation_provider.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_event.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/viewmodels/calendar_home_vm.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/calendar_format.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/event_card.dart';

/// One day of the agenda: header + cards. Empty days collapse to a single thin
/// "Nothing planned" row; today is always expanded and highlighted.
class DaySectionTile extends StatelessWidget {
  const DaySectionTile({
    super.key,
    required this.section,
    required this.onEventTap,
  });

  static const nothingPlanned = 'Nothing planned';

  final DaySection section;
  final ValueChanged<CalendarEvent> onEventTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isToday = section.isToday;

    if (section.isEmpty && !isToday) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Row(
          children: [
            Text(
              formatDayHeader(context, section.day, isToday: false),
              style:
                  theme.textTheme.labelMedium?.copyWith(color: scheme.outline),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                nothingPlanned,
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: scheme.outline),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: DecoratedBox(
            decoration: isToday
                ? BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  )
                : const BoxDecoration(),
            child: Padding(
              padding: isToday
                  ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
                  : EdgeInsets.zero,
              child: Text(
                formatDayHeader(context, section.day, isToday: isToday),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isToday ? scheme.onPrimary : scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
        if (section.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              '$nothingPlanned today',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          )
        else
          for (final e in section.events)
            _EventTile(
              key: ValueKey(e.id.value),
              event: e,
              onTap: () => onEventTap(e),
            ),
      ],
    );
  }
}

/// Resolves the author chip through the same provider chat uses — no new
/// nickname/colour lookup.
class _EventTile extends ConsumerWidget {
  const _EventTile({super.key, required this.event, required this.onTap});

  final CalendarEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(memberPresentationProvider(event.createdBy.value));
    return EventCard(
      event: event,
      authorNickname: member.nickname,
      authorColor: member.nameColor,
      onTap: onTap,
    );
  }
}
