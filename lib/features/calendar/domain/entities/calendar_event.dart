import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/event_attachment_ref.dart';

/// A single-day calendar event in a base.
///
/// All instants are **UTC**; presentation converts to device-local. All-day
/// events store local midnight of the chosen day (converted to UTC) in
/// [startAt] and `null` [endAt]. See FIRESTORE_SCHEMA.md §Calendar for the
/// wire shape (`bases/{baseId}/events/{eventId}`).
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.baseId,
    required this.title,
    required this.startAt,
    required this.allDay,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.endAt,
    this.notes,
    this.attachments = const [],
  });

  final EventId id;
  final BaseId baseId;
  final String title;

  /// UTC.
  final DateTime startAt;

  /// UTC; null = no explicit end. Never before [startAt].
  final DateTime? endAt;
  final bool allDay;
  final String? notes;
  final UserId createdBy;

  /// UTC.
  final DateTime createdAt;

  /// UTC.
  final DateTime updatedAt;

  /// Reserved extension point (always empty in MVP — see
  /// [EventAttachmentRef]). The Firestore codec neither reads nor writes it.
  final List<EventAttachmentRef> attachments;

  CalendarEvent copyWith({
    String? title,
    DateTime? startAt,
    DateTime? endAt,
    bool clearEndAt = false,
    bool? allDay,
    String? notes,
    bool clearNotes = false,
    DateTime? updatedAt,
  }) =>
      CalendarEvent(
        id: id,
        baseId: baseId,
        title: title ?? this.title,
        startAt: startAt ?? this.startAt,
        endAt: clearEndAt ? null : (endAt ?? this.endAt),
        allDay: allDay ?? this.allDay,
        notes: clearNotes ? null : (notes ?? this.notes),
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        attachments: attachments,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CalendarEvent &&
        other.id == id &&
        other.baseId == baseId &&
        other.title == title &&
        other.startAt == startAt &&
        other.endAt == endAt &&
        other.allDay == allDay &&
        other.notes == notes &&
        other.createdBy == createdBy &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        baseId,
        title,
        startAt,
        endAt,
        allDay,
        notes,
        createdBy,
        createdAt,
        updatedAt,
      );

  @override
  String toString() =>
      'CalendarEvent(id: $id, title: $title, startAt: $startAt, allDay: $allDay)';
}
