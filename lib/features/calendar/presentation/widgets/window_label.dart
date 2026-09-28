import 'package:flutter/material.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_window.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/calendar_format.dart';

/// One-line window label with the owner-only Settings control.
///
/// The control stays named Settings. The week/month expander on the grid
/// header is a different control and does not open this dialog.
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
          Icon(
            Icons.date_range_outlined,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              formatWindowLabel(window),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isOwner)
            TextButton.icon(
              key: gearKey,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: scheme.onSurfaceVariant,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                textStyle: const TextStyle(
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: const Text('Settings'),
            ),
        ],
      ),
    );
  }
}
