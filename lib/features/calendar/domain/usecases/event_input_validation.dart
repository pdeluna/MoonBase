import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/validators.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_window.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/event_input.dart';

/// Shared by `CreateEvent` and `UpdateEvent` so the two cannot disagree about
/// what "a valid event" is. Returns `null` when [input] is acceptable.
///
/// Caps mirror `firestore.rules` (`eventFieldsValid`); the inside-window check
/// is client policy only (rules do not know the window).
ValidationFailure? validateEventInput(
  EventInput input, {
  required CalendarWindow window,
  required DateTime today,
}) {
  if (!isValidEventTitle(input.title)) {
    return const ValidationFailure(
      'Title must be 1–$kEventTitleMaxLen characters.',
    );
  }
  if (!isValidEventNotes(input.notes)) {
    return const ValidationFailure(
      'Notes can\'t exceed $kEventNotesMaxLen characters.',
    );
  }
  final end = input.endAt;
  if (end != null && end.isBefore(input.startAt)) {
    return const ValidationFailure('End time must not be before start time.');
  }
  if (!window.resolve(today).contains(input.startAt)) {
    return ValidationFailure(
      'Pick a day inside the visible window '
      '(${window.pastDays} days back · ${window.futureDays} days ahead).',
    );
  }
  return null;
}
