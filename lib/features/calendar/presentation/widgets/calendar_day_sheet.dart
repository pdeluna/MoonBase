import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/features/auth/presentation/providers/member_presentation_provider.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_event.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/calendar_home_actions.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/event_card.dart';

/// Opens the existing detail sheet for one event, or a short sheet of
/// [EventCard]s when the day has several. Empty days are not tappable.
Future<void> showCalendarDay(
  BuildContext context,
  WidgetRef ref,
  List<CalendarEvent> events,
) {
  if (events.isEmpty) return Future.value();
  if (events.length == 1) return showEventDetail(context, ref, events.first);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder:
        (sheetContext) => CalendarDaySheet(
          events: events,
          onEventTap: (event) => showEventDetail(sheetContext, ref, event),
        ),
  );
}

/// Several events on one day. Each card opens [showEventDetail].
class CalendarDaySheet extends ConsumerWidget {
  const CalendarDaySheet({
    super.key,
    required this.events,
    required this.onEventTap,
  });

  static const sheetKey = Key('calendar-day-sheet');

  final List<CalendarEvent> events;
  final ValueChanged<CalendarEvent> onEventTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      key: sheetKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final event in events)
              _DayEventTile(
                key: ValueKey(event.id.value),
                event: event,
                onTap: () => onEventTap(event),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayEventTile extends ConsumerWidget {
  const _DayEventTile({super.key, required this.event, required this.onTap});

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
