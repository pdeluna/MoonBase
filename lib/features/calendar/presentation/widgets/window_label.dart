import 'package:flutter/material.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_window.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/calendar_format.dart';

/// One-line window label with the owner-only settings gear.
class WindowLabel extends StatelessWidget {
  const WindowLabel({
    super.key,
    required this.window,
    required this.isOwner,
    required this.onOpenSettings,
  });

  static const gearKey = Key('calendar-settings-gear');

  final CalendarWindow window;
  final bool isOwner;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          Icon(Icons.date_range_outlined,
              size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              formatWindowLabel(window),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isOwner)
            IconButton(
              key: gearKey,
              tooltip: 'Calendar settings',
              visualDensity: VisualDensity.compact,
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined, size: 20),
            ),
        ],
      ),
    );
  }
}
