import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/features/auth/presentation/providers/member_presentation_provider.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_event.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/viewmodels/calendar_home_vm.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/calendar_tokens.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/event_card.dart';

/// Events for the selected day, or the empty copy and an Add button.
class DayAgenda extends StatelessWidget {
  const DayAgenda({
    super.key,
    required this.day,
    required this.isToday,
    required this.events,
    required this.canAdd,
    required this.onEventTap,
    required this.onAdd,
  });

  static const emptyCopy = 'Nothing planned yet.';
  static const addKey = Key('calendar-agenda-add');

  final DayKey day;
  final bool isToday;
  final List<CalendarEvent> events;
  final bool canAdd;
  final ValueChanged<CalendarEvent> onEventTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    final overline = isToday
        ? 'ON THE CALENDAR'
        : 'ON THE CALENDAR · ${l10n.formatMediumDate(day.localMidnight).toUpperCase()}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(overline, style: CalendarTokens.overline(context)),
          const SizedBox(height: 10),
          if (events.isEmpty)
            _EmptyDay(canAdd: canAdd, onAdd: onAdd)
          else
            for (var i = 0; i < events.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _AgendaCard(event: events[i], onTap: onEventTap),
            ],
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.canAdd, required this.onAdd});

  final bool canAdd;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final secondary = CalendarTokens.of(context).secondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DayAgenda.emptyCopy,
          style: TextStyle(fontSize: 15, color: secondary),
        ),
        if (canAdd)
          TextButton(
            key: DayAgenda.addKey,
            style: TextButton.styleFrom(
              foregroundColor: CalendarTokens.accent,
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
              minimumSize: const Size(44, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              alignment: Alignment.centerLeft,
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
            onPressed: onAdd,
            child: const Text('Add event'),
          ),
      ],
    );
  }
}

class _AgendaCard extends ConsumerWidget {
  const _AgendaCard({required this.event, required this.onTap});

  final CalendarEvent event;
  final ValueChanged<CalendarEvent> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(
      memberPresentationProvider(event.createdBy.value),
    );
    return EventCard(
      event: event,
      authorNickname: member.nickname,
      onTap: () => onTap(event),
    );
  }
}
