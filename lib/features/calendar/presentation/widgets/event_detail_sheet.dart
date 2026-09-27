import 'package:flutter/material.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_event.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/calendar_format.dart';

/// Read view of one event. Edit / Delete appear only when [canModify]
/// (author-or-owner — the same predicate the use cases enforce).
class EventDetailSheet extends StatelessWidget {
  const EventDetailSheet({
    super.key,
    required this.event,
    required this.authorNickname,
    required this.authorColor,
    required this.canModify,
    required this.onEdit,
    required this.onDelete,
  });

  static const editKey = Key('event-detail-edit');
  static const deleteKey = Key('event-detail-delete');

  final CalendarEvent event;
  final String authorNickname;
  final Color authorColor;
  final bool canModify;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final notes = event.notes;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(event.title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.event_outlined,
                    size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(formatEventDate(context, event)),
                const SizedBox(width: 16),
                Icon(Icons.schedule_outlined,
                    size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(formatEventTime(context, event)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: authorColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  'Added by $authorNickname',
                  style:
                      theme.textTheme.bodyMedium?.copyWith(color: authorColor),
                ),
              ],
            ),
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(notes, style: theme.textTheme.bodyLarge),
            ],
            if (canModify) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: deleteKey,
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      key: editKey,
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
