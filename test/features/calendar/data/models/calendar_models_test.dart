import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/calendar/data/models/calendar_event_model.dart';
import 'package:moonbase_skeleton/features/calendar/data/models/calendar_settings_model.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_event.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_settings.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_window.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/event_creation_policy.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/event_input.dart';

void main() {
  /// Must equal the rules `hasOnly` list for events (firestore.rules
  /// `eventFieldsValid`). If this test changes, the rules change with it.
  const eventWireKeys = {
    'title',
    'startAt',
    'endAt',
    'allDay',
    'notes',
    'createdBy',
    'createdAt',
    'updatedAt',
    'schemaVersion',
  };
  const settingsWireKeys = {
    'pastDays',
    'futureDays',
    'eventCreation',
    'updatedAt',
    'schemaVersion',
  };

  final start = DateTime.utc(2026, 9, 27, 18);
  final end = DateTime.utc(2026, 9, 27, 20);

  group('CalendarEventModel', () {
    test(
        'toFirestoreCreate emits exactly the rules hasOnly keys, schemaVersion 1',
        () {
      final m = CalendarEventModel(
        id: 'e1',
        baseId: 'b1',
        title: 'Dinner',
        startAt: start,
        endAt: end,
        allDay: false,
        notes: 'Bring dessert',
        createdBy: 'u1',
        createdAt: start,
        updatedAt: start,
      );
      final map = m.toFirestoreCreate();
      expect(map.keys.toSet(), eventWireKeys);
      expect(map['schemaVersion'], 1);
      expect(map['createdAt'], isA<FieldValue>());
      expect(map['updatedAt'], isA<FieldValue>());
      expect(map['startAt'], Timestamp.fromDate(start));
      expect(map['endAt'], Timestamp.fromDate(end));
      expect(map['createdBy'], 'u1');
      // Reserved extension point is never written.
      expect(map.containsKey('attachmentPaths'), isFalse);
      expect(map.containsKey('attachments'), isFalse);
    });

    test('toFirestoreUpdate never sends createdBy / createdAt', () {
      final map = CalendarEventModel.toFirestoreUpdate(EventInput(
        title: 'Lunch',
        startAt: start,
        allDay: true,
      ));
      expect(map.keys.toSet(),
          {'title', 'startAt', 'endAt', 'allDay', 'notes', 'updatedAt'});
      expect(map['endAt'], isNull);
      expect(map['notes'], isNull);
      expect(map['updatedAt'], isA<FieldValue>());
      expect(eventWireKeys.containsAll(map.keys), isTrue);
    });

    test('fromFirestore round-trips Timestamps to UTC and null endAt/notes',
        () {
      final m = CalendarEventModel.fromFirestore('e1', 'b1', {
        'title': 'Dinner',
        'startAt': Timestamp.fromDate(start),
        'endAt': null,
        'allDay': false,
        'notes': null,
        'createdBy': 'u1',
        'createdAt': Timestamp.fromDate(start),
        'updatedAt': Timestamp.fromDate(end),
        'schemaVersion': 1,
      });
      expect(m.startAt, start);
      expect(m.startAt.isUtc, isTrue);
      expect(m.endAt, isNull);
      expect(m.notes, isNull);
      expect(m.updatedAt, end);
      final e = m.toEntity();
      expect(e.id, 'e1'.eid);
      expect(e.baseId, 'b1'.bid);
      expect(e.createdBy, 'u1'.uid);
      expect(e.attachments, isEmpty);
    });

    test(
        'pending serverTimestamp (null createdAt/updatedAt) maps to a now stand-in',
        () {
      final before = DateTime.now().toUtc();
      final m = CalendarEventModel.fromFirestore('e1', 'b1', {
        'title': 'Dinner',
        'startAt': Timestamp.fromDate(start),
        'allDay': true,
        'createdBy': 'u1',
        'schemaVersion': 1,
      });
      expect(m.createdAt.isBefore(before), isFalse);
      expect(m.updatedAt.isBefore(before), isFalse);
      expect(m.allDay, isTrue);
    });

    test('entity → model → entity is lossless for wire fields', () {
      final e = CalendarEvent(
        id: 'e1'.eid,
        baseId: 'b1'.bid,
        title: 'Dinner',
        startAt: start,
        endAt: end,
        allDay: false,
        notes: 'n',
        createdBy: 'u1'.uid,
        createdAt: start,
        updatedAt: end,
      );
      expect(CalendarEventModel.fromEntity(e).toEntity(), e);
    });
  });

  group('CalendarSettingsModel', () {
    test('missing doc ⇒ CalendarSettings.defaults (the one defaults constant)',
        () {
      expect(
          CalendarSettingsModel.fromFirestore(null), CalendarSettings.defaults);
      expect(
          identical(CalendarSettingsModel.fromFirestore(null),
              CalendarSettings.defaults),
          isTrue);
    });

    test(
        'toFirestore emits exactly the rules hasOnly keys with wire policy values',
        () {
      final map = CalendarSettingsModel.toFirestore(const CalendarSettings(
        window: CalendarWindow(pastDays: 0, futureDays: 7),
        eventCreation: EventCreationPolicy.ownerOnly,
      ));
      expect(map.keys.toSet(), settingsWireKeys);
      expect(map['pastDays'], 0);
      expect(map['futureDays'], 7);
      expect(map['eventCreation'], 'owner');
      expect(map['schemaVersion'], 1);
      expect(map['updatedAt'], isA<FieldValue>());
      expect(
        CalendarSettingsModel.toFirestore(
            CalendarSettings.defaults)['eventCreation'],
        'members',
      );
    });

    test('fromFirestore maps wire values and clamps out-of-range days', () {
      final s = CalendarSettingsModel.fromFirestore({
        'pastDays': 14,
        'futureDays': 900,
        'eventCreation': 'owner',
        'schemaVersion': 1,
      });
      expect(s.window, const CalendarWindow(pastDays: 14, futureDays: 365));
      expect(s.eventCreation, EventCreationPolicy.ownerOnly);
    });

    test('unknown policy wire value falls back to the default policy', () {
      expect(
        CalendarSettingsModel.policyFromWire('anyone'),
        CalendarSettings.defaults.eventCreation,
      );
      expect(CalendarSettingsModel.policyFromWire('members'),
          EventCreationPolicy.allMembers);
      expect(CalendarSettingsModel.policyFromWire('owner'),
          EventCreationPolicy.ownerOnly);
    });

    test('settings round-trip through wire policy strings', () {
      for (final p in EventCreationPolicy.values) {
        expect(
          CalendarSettingsModel.policyFromWire(
              CalendarSettingsModel.policyToWire(p)),
          p,
        );
      }
    });
  });
}
