import 'package:flutter/material.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/validators.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_settings.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_window.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/event_creation_policy.dart';

/// Owner-only: visible window presets + custom steppers, and who may add
/// events. Saves the whole settings doc through [onSubmit].
class CalendarSettingsDialog extends StatefulWidget {
  const CalendarSettingsDialog({
    super.key,
    required this.initial,
    required this.onSubmit,
  });

  static const saveKey = Key('calendar-settings-save');
  static const membersKey = Key('calendar-settings-members');
  static const ownerKey = Key('calendar-settings-owner');

  /// Presets (label → window). "Month" is the accepted default (D-2) and is
  /// the same object as `CalendarWindow.defaults` so it cannot drift.
  static const presets = <String, CalendarWindow>{
    'Week': CalendarWindow(pastDays: 0, futureDays: 7),
    'Two weeks': CalendarWindow(pastDays: 7, futureDays: 14),
    'Month': CalendarWindow.defaults,
    'Quarter': CalendarWindow(pastDays: 14, futureDays: 90),
  };

  final CalendarSettings initial;
  final Future<Failure?> Function(CalendarSettings settings) onSubmit;

  @override
  State<CalendarSettingsDialog> createState() => _CalendarSettingsDialogState();
}

class _CalendarSettingsDialogState extends State<CalendarSettingsDialog> {
  late int _past;
  late int _future;
  late EventCreationPolicy _policy;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _past = widget.initial.window.pastDays;
    _future = widget.initial.window.futureDays;
    _policy = widget.initial.eventCreation;
  }

  CalendarWindow get _window =>
      CalendarWindow(pastDays: _past, futureDays: _future);

  String? get _selectedPreset {
    for (final entry in CalendarSettingsDialog.presets.entries) {
      if (entry.value == _window) return entry.key;
    }
    return null;
  }

  void _setDays({int? past, int? future}) => setState(() {
        if (past != null) _past = past.clamp(0, kCalendarWindowMaxDays);
        if (future != null) _future = future.clamp(0, kCalendarWindowMaxDays);
      });

  Future<void> _save() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final failure = await widget.onSubmit(
      CalendarSettings(window: _window, eventCreation: _policy),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (failure == null) {
      Navigator.of(context).pop();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(failure.message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _selectedPreset;
    return AlertDialog(
      title: const Text('Calendar settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Visible window', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final entry in CalendarSettingsDialog.presets.entries)
                  ChoiceChip(
                    label: Text(entry.key),
                    selected: selected == entry.key,
                    onSelected: (_) => _setDays(
                      past: entry.value.pastDays,
                      future: entry.value.futureDays,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _Stepper(
              label: 'Days back',
              value: _past,
              onChanged: (v) => _setDays(past: v),
            ),
            _Stepper(
              label: 'Days ahead',
              value: _future,
              onChanged: (v) => _setDays(future: v),
            ),
            const SizedBox(height: 16),
            Text('Who can add events', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<EventCreationPolicy>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: EventCreationPolicy.allMembers,
                  label: Text('All members',
                      key: CalendarSettingsDialog.membersKey),
                  icon: Icon(Icons.groups_outlined),
                ),
                ButtonSegment(
                  value: EventCreationPolicy.ownerOnly,
                  label:
                      Text('Owner only', key: CalendarSettingsDialog.ownerKey),
                  icon: Icon(Icons.lock_outline),
                ),
              ],
              selected: {_policy},
              onSelectionChanged: (s) => setState(() => _policy = s.first),
            ),
            if (_policy == EventCreationPolicy.ownerOnly)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Members can still edit or delete events they already added.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: CalendarSettingsDialog.saveKey,
          onPressed: _submitting ? null : _save,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          tooltip: 'Fewer $label',
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: 'More $label',
          onPressed: value < kCalendarWindowMaxDays
              ? () => onChanged(value + 1)
              : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}
