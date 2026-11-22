import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_event.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/event_input.dart';

/// Persistence DTO for `bases/{baseId}/events/{eventId}`.
///
/// Wire keys are exactly the rules `hasOnly` list: `title, startAt, endAt,
/// allDay, notes, createdBy, createdAt, updatedAt, schemaVersion`. The
/// reserved `attachments` extension point on the entity is **not** mapped —
/// adding `attachmentPaths` is an additive rules + codec change
/// (FIRESTORE_UPDATE_TRIGGERS #20).
class CalendarEventModel {
  const CalendarEventModel({
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
  });

  /// Firestore doc → model.
  ///
  /// Pending local writes have null `createdAt` / `updatedAt` until the
  /// server timestamp resolves; those map to [DateTime.now] (UTC) so the
  /// post-map sort stays coherent (same as chat).
  factory CalendarEventModel.fromFirestore(
    String id,
    String baseId,
    Map<String, dynamic> data,
  ) {
    final now = DateTime.now().toUtc();
    return CalendarEventModel(
      id: id,
      baseId: baseId,
      title: data['title'] as String? ?? '',
      startAt: _instant(data['startAt']) ?? now,
      endAt: _instant(data['endAt']),
      allDay: data['allDay'] as bool? ?? false,
      notes: data['notes'] as String?,
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: _instant(data['createdAt']) ?? now,
      updatedAt: _instant(data['updatedAt']) ?? now,
    );
  }

  factory CalendarEventModel.fromEntity(CalendarEvent e) => CalendarEventModel(
        id: e.id.value,
        baseId: e.baseId.value,
        title: e.title,
        startAt: e.startAt.toUtc(),
        endAt: e.endAt?.toUtc(),
        allDay: e.allDay,
        notes: e.notes,
        createdBy: e.createdBy.value,
        createdAt: e.createdAt.toUtc(),
        updatedAt: e.updatedAt.toUtc(),
      );

  static const firestoreSchemaVersion = 1;

  final String id;
  final String baseId;
  final String title;
  final DateTime startAt;
  final DateTime? endAt;
  final bool allDay;
  final String? notes;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  CalendarEvent toEntity() => CalendarEvent(
        id: id.eid,
        baseId: baseId.bid,
        title: title,
        startAt: startAt,
        endAt: endAt,
        allDay: allDay,
        notes: notes,
        createdBy: createdBy.uid,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  /// Full create payload. `createdAt` / `updatedAt` are server timestamps.
  Map<String, dynamic> toFirestoreCreate() => <String, dynamic>{
        ..._editableFields(),
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'schemaVersion': firestoreSchemaVersion,
      };

  /// Partial update payload for `DocumentReference.update` — editable fields
  /// plus a fresh `updatedAt`. `createdBy` / `createdAt` are never sent
  /// (rules pin them immutable).
  static Map<String, dynamic> toFirestoreUpdate(EventInput input) =>
      <String, dynamic>{
        ..._editableFieldsFrom(
          title: input.title,
          startAt: input.startAt,
          endAt: input.endAt,
          allDay: input.allDay,
          notes: input.notes,
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> _editableFields() => _editableFieldsFrom(
        title: title,
        startAt: startAt,
        endAt: endAt,
        allDay: allDay,
        notes: notes,
      );

  static Map<String, dynamic> _editableFieldsFrom({
    required String title,
    required DateTime startAt,
    required DateTime? endAt,
    required bool allDay,
    required String? notes,
  }) =>
      <String, dynamic>{
        'title': title,
        'startAt': Timestamp.fromDate(startAt.toUtc()),
        'endAt': endAt == null ? null : Timestamp.fromDate(endAt.toUtc()),
        'allDay': allDay,
        'notes': notes,
      };
}

DateTime? _instant(Object? raw) => switch (raw) {
      Timestamp ts => ts.toDate().toUtc(),
      DateTime dt => dt.toUtc(),
      _ => null,
    };
