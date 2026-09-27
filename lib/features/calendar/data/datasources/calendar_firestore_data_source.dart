import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:uuid/uuid.dart';

import 'package:moonbase_skeleton/features/calendar/data/datasources/calendar_data_source.dart';
import 'package:moonbase_skeleton/features/calendar/data/models/calendar_event_batch.dart';
import 'package:moonbase_skeleton/features/calendar/data/models/calendar_event_model.dart';
import 'package:moonbase_skeleton/features/calendar/data/models/calendar_settings_model.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_feed.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_settings.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/event_input.dart';

/// Cloud Firestore calendar — `bases/{baseId}/events/{eventId}` and
/// `bases/{baseId}/settings/calendar`.
///
/// Event ids are client-generated ([Uuid] v4, as chat). Writes carry
/// `schemaVersion: 1` and server timestamps. The feed is a range + orderBy on
/// the single `startAt` field (no composite index) capped at
/// [kCalendarFeedLimit], `snapshots(includeMetadataChanges: true)` so the
/// cache→live transition is observable (R5). After mapping, the list is
/// re-sorted by `startAt` then `createdAt` so pending server-timestamp
/// stand-ins do not jump.
class CalendarFirestoreDataSource implements CalendarDataSource {
  CalendarFirestoreDataSource({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
    Uuid? uuid,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance,
        _uuid = uuid ?? const Uuid();

  final FirebaseFirestore _db;
  final fb.FirebaseAuth _auth;
  final Uuid _uuid;

  CollectionReference<Map<String, dynamic>> _eventsCol(String baseId) =>
      _db.collection('bases').doc(baseId).collection('events');

  DocumentReference<Map<String, dynamic>> _settingsRef(String baseId) => _db
      .collection('bases')
      .doc(baseId)
      .collection('settings')
      .doc(CalendarSettingsModel.docId);

  @override
  Stream<CalendarEventBatch> watchEvents({
    required String baseId,
    required DateTime fromUtc,
    required DateTime toExclusiveUtc,
  }) {
    return _eventsCol(baseId)
        .where('startAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(fromUtc.toUtc()))
        .where('startAt',
            isLessThan: Timestamp.fromDate(toExclusiveUtc.toUtc()))
        .orderBy('startAt')
        .limit(kCalendarFeedLimit)
        .snapshots(includeMetadataChanges: true)
        .map((snap) {
      final list = snap.docs
          .map((d) => CalendarEventModel.fromFirestore(d.id, baseId, d.data()))
          .toList()
        ..sort((a, b) {
          final byStart = a.startAt.compareTo(b.startAt);
          return byStart != 0 ? byStart : a.createdAt.compareTo(b.createdAt);
        });
      return CalendarEventBatch(
        events: list,
        fromCache: snap.metadata.isFromCache,
      );
    });
  }

  @override
  Future<CalendarEventModel> createEvent({
    required String baseId,
    required String createdBy,
    required EventInput input,
  }) async {
    final authUid = _auth.currentUser?.uid;
    if (authUid == null || authUid != createdBy) {
      throw StateError(
        'createEvent requires a signed-in user matching createdBy',
      );
    }

    final eventId = _uuid.v4();
    final now = DateTime.now().toUtc();
    final model = CalendarEventModel(
      id: eventId,
      baseId: baseId,
      title: input.title,
      startAt: input.startAt.toUtc(),
      endAt: input.endAt?.toUtc(),
      allDay: input.allDay,
      notes: input.notes,
      createdBy: createdBy,
      createdAt: now,
      updatedAt: now,
    );

    await _eventsCol(baseId).doc(eventId).set(model.toFirestoreCreate());
    return model;
  }

  @override
  Future<void> updateEvent({
    required String baseId,
    required String eventId,
    required EventInput input,
  }) =>
      _eventsCol(baseId)
          .doc(eventId)
          .update(CalendarEventModel.toFirestoreUpdate(input));

  @override
  Future<void> deleteEvent({
    required String baseId,
    required String eventId,
  }) =>
      _eventsCol(baseId).doc(eventId).delete();

  @override
  Future<CalendarSettings> getSettings({required String baseId}) async {
    final snap = await _settingsRef(baseId).get();
    return CalendarSettingsModel.fromFirestore(
        snap.exists ? snap.data() : null);
  }

  @override
  Future<void> setSettings({
    required String baseId,
    required CalendarSettings settings,
  }) =>
      _settingsRef(baseId).set(CalendarSettingsModel.toFirestore(settings));
}
