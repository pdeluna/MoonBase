/// Editable fields of an event, as submitted by the editor.
///
/// Instants are UTC (the editor converts from device-local before building
/// this). Validation lives in `validateEventInput` (use-case layer), not here.
class EventInput {
  const EventInput({
    required this.title,
    required this.startAt,
    required this.allDay,
    this.endAt,
    this.notes,
  });

  final String title;

  /// UTC.
  final DateTime startAt;

  /// UTC; null = no explicit end.
  final DateTime? endAt;
  final bool allDay;
  final String? notes;

  /// Trimmed title; blank notes collapse to null so the wire never carries `''`.
  EventInput normalized() {
    final trimmedNotes = notes?.trim();
    return EventInput(
      title: title.trim(),
      startAt: startAt.toUtc(),
      endAt: endAt?.toUtc(),
      allDay: allDay,
      notes:
          (trimmedNotes == null || trimmedNotes.isEmpty) ? null : trimmedNotes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventInput &&
          other.title == title &&
          other.startAt == startAt &&
          other.endAt == endAt &&
          other.allDay == allDay &&
          other.notes == notes);

  @override
  int get hashCode => Object.hash(title, startAt, endAt, allDay, notes);
}
