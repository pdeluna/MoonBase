import 'package:flutter/material.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/presentation/failure_snackbar.dart';
import 'package:moonbase_skeleton/core/validators.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_event.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_window.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/event_input.dart';

/// Create / edit sheet. Owns draft state; emits one [EventInput] through
/// [onSubmit] and stays open (showing the `Failure`) when the submit fails.
///
/// Client-side checks mirror `validateEventInput` so obvious mistakes never
/// leave the sheet; the use case remains the authority.
class EventEditorSheet extends StatefulWidget {
  const EventEditorSheet({
    super.key,
    required this.window,
    required this.today,
    required this.onSubmit,
    this.existing,
  });

  static const saveKey = Key('event-editor-save');
  static const titleKey = Key('event-editor-title');
  static const notesKey = Key('event-editor-notes');
  static const allDayKey = Key('event-editor-all-day');
  static const startKey = Key('event-editor-start');
  static const endKey = Key('event-editor-end');

  static const titleError = 'Title needs 1–$kEventTitleMaxLen characters.';
  static const notesError = 'Notes are too long.';
  static const endBeforeStartError = 'End time must not be before start time.';

  final CalendarWindow window;
  final DateTime today;
  final CalendarEvent? existing;
  final Future<Failure?> Function(EventInput input) onSubmit;

  @override
  State<EventEditorSheet> createState() => _EventEditorSheetState();
}

class _EventEditorSheetState extends State<EventEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late DateTime _date;
  late bool _allDay;
  late TimeOfDay _start;
  TimeOfDay? _end;
  String? _timeError;
  bool _submitting = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    final startLocal = e?.startAt.toLocal() ?? widget.today.toLocal();
    _date = DateTime(startLocal.year, startLocal.month, startLocal.day);
    _allDay = e?.allDay ?? false;
    _start = e == null
        ? _roundToNextHour(TimeOfDay.fromDateTime(startLocal))
        : TimeOfDay.fromDateTime(startLocal);
    final endLocal = e?.endAt?.toLocal();
    _end = endLocal == null ? null : TimeOfDay.fromDateTime(endLocal);
  }

  static TimeOfDay _roundToNextHour(TimeOfDay t) =>
      TimeOfDay(hour: (t.hour + 1) % 24, minute: 0);

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  DateTime _combine(DateTime day, TimeOfDay t) =>
      DateTime(day.year, day.month, day.day, t.hour, t.minute);

  int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  EventInput _buildInput() {
    final startAt = _allDay ? _date : _combine(_date, _start);
    final end = _end;
    final endAt = (_allDay || end == null) ? null : _combine(_date, end);
    return EventInput(
      title: _title.text,
      startAt: startAt.toUtc(),
      endAt: endAt?.toUtc(),
      allDay: _allDay,
      notes: _notes.text,
    );
  }

  Future<void> _pickDate() async {
    final range = widget.window.resolve(widget.today);
    final first = range.from.toLocal();
    final last = range.toExclusive.toLocal().subtract(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _date.isBefore(first) ? first : (_date.isAfter(last) ? last : _date),
      firstDate: DateTime(first.year, first.month, first.day),
      lastDate: DateTime(last.year, last.month, last.day),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickStart() async {
    final t = await showTimePicker(context: context, initialTime: _start);
    if (t != null && mounted) {
      setState(() {
        _start = t;
        _timeError = null;
      });
    }
  }

  Future<void> _pickEnd() async {
    final t =
        await showTimePicker(context: context, initialTime: _end ?? _start);
    if (t != null && mounted) {
      setState(() {
        _end = t;
        _timeError = null;
      });
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final formOk = _formKey.currentState!.validate();
    final end = _end;
    if (!_allDay && end != null && _minutes(end) < _minutes(_start)) {
      setState(() => _timeError = EventEditorSheet.endBeforeStartError);
      return;
    }
    if (!formOk) return;

    setState(() => _submitting = true);
    final failure = await widget.onSubmit(_buildInput());
    if (!mounted) return;
    setState(() => _submitting = false);
    if (failure == null) {
      Navigator.of(context).pop();
      return;
    }
    showFailureSnackBar(context, failure);
  }

  @override
  Widget build(BuildContext context) {
    final l = MaterialLocalizations.of(context);
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isEdit ? 'Edit event' : 'New event',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: EventEditorSheet.titleKey,
                  controller: _title,
                  autofocus: !_isEdit,
                  maxLength: kEventTitleMaxLen,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'What\'s happening?',
                  ),
                  validator: (v) => isValidEventTitle(v ?? '')
                      ? null
                      : EventEditorSheet.titleError,
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: Text(l.formatFullDate(_date)),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: _pickDate,
                ),
                SwitchListTile(
                  key: EventEditorSheet.allDayKey,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('All day'),
                  value: _allDay,
                  onChanged: (v) => setState(() {
                    _allDay = v;
                    _timeError = null;
                  }),
                ),
                if (!_allDay)
                  Row(
                    children: [
                      Expanded(
                        child: _TimeField(
                          key: EventEditorSheet.startKey,
                          label: 'Start',
                          value: l.formatTimeOfDay(_start),
                          onTap: _pickStart,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TimeField(
                          key: EventEditorSheet.endKey,
                          label: 'End (optional)',
                          value: _end == null ? '—' : l.formatTimeOfDay(_end!),
                          onTap: _pickEnd,
                          onClear: _end == null
                              ? null
                              : () => setState(() {
                                    _end = null;
                                    _timeError = null;
                                  }),
                        ),
                      ),
                    ],
                  ),
                if (_timeError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _timeError!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.error),
                    ),
                  ),
                const SizedBox(height: 8),
                TextFormField(
                  key: EventEditorSheet.notesKey,
                  controller: _notes,
                  maxLength: kEventNotesMaxLen,
                  maxLines: 3,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) =>
                      isValidEventNotes(v) ? null : EventEditorSheet.notesError,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: EventEditorSheet.saveKey,
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isEdit ? 'Save changes' : 'Add event'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: onClear == null
              ? const Icon(Icons.schedule_outlined)
              : IconButton(
                  tooltip: 'Clear end time',
                  icon: const Icon(Icons.close),
                  onPressed: onClear,
                ),
        ),
        child: Text(value),
      ),
    );
  }
}
