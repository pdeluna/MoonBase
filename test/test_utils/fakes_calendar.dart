import 'dart:async';

import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/calendar/data/datasources/calendar_data_source.dart';
import 'package:moonbase_skeleton/features/calendar/data/models/calendar_event_batch.dart';
import 'package:moonbase_skeleton/features/calendar/data/models/calendar_event_model.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_event.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_settings.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/event_input.dart';

/// In-memory `CalendarDataSource` for repository / controller tests.
///
/// Emits a batch on every mutation; [fromCache] controls the freshness flag of
/// the next emissions. Set [throwOn] to make a method throw (guard mapping).
class InMemoryCalendarDataSource implements CalendarDataSource {
  InMemoryCalendarDataSource({DateTime Function()? now})
      : _now = now ?? (() => DateTime.now().toUtc());

  final DateTime Function() _now;
  final Map<String, Map<String, CalendarEventModel>> _events = {};
  final Map<String, CalendarSettings> _settings = {};
  final _controllers = <StreamController<CalendarEventBatch>>[];
  final _watched = <StreamController<CalendarEventBatch>,
      ({String baseId, DateTime from, DateTime to})>{};

  bool fromCache = false;
  Object? throwOn;
  int settingsReads = 0;
  int nextId = 0;

  List<CalendarEventModel> eventsFor(String baseId) =>
      (_events[baseId] ?? {}).values.toList();

  void _emitAll() {
    for (final c in _controllers) {
      final spec = _watched[c]!;
      c.add(_batch(spec.baseId, spec.from, spec.to));
    }
  }

  CalendarEventBatch _batch(String baseId, DateTime from, DateTime to) {
    final list = eventsFor(baseId)
        .where((e) => !e.startAt.isBefore(from) && e.startAt.isBefore(to))
        .toList()
      ..sort((a, b) {
        final s = a.startAt.compareTo(b.startAt);
        return s != 0 ? s : a.createdAt.compareTo(b.createdAt);
      });
    return CalendarEventBatch(events: list, fromCache: fromCache);
  }

  void _maybeThrow() {
    final t = throwOn;
    if (t != null) throw t;
  }

  @override
  Stream<CalendarEventBatch> watchEvents({
    required String baseId,
    required DateTime fromUtc,
    required DateTime toExclusiveUtc,
  }) {
    late StreamController<CalendarEventBatch> c;
    c = StreamController<CalendarEventBatch>(
      onListen: () {
        final t = throwOn;
        if (t != null) {
          c.addError(t);
          return;
        }
        c.add(_batch(baseId, fromUtc, toExclusiveUtc));
      },
      onCancel: () {
        _controllers.remove(c);
        _watched.remove(c);
      },
    );
    _controllers.add(c);
    _watched[c] = (baseId: baseId, from: fromUtc, to: toExclusiveUtc);
    return c.stream;
  }

  int get activeListeners => _controllers.length;

  @override
  Future<CalendarEventModel> createEvent({
    required String baseId,
    required String createdBy,
    required EventInput input,
  }) async {
    _maybeThrow();
    final now = _now();
    final m = CalendarEventModel(
      id: 'e${nextId++}',
      baseId: baseId,
      title: input.title,
      startAt: input.startAt,
      endAt: input.endAt,
      allDay: input.allDay,
      notes: input.notes,
      createdBy: createdBy,
      createdAt: now,
      updatedAt: now,
    );
    (_events[baseId] ??= {})[m.id] = m;
    _emitAll();
    return m;
  }

  @override
  Future<void> updateEvent({
    required String baseId,
    required String eventId,
    required EventInput input,
  }) async {
    _maybeThrow();
    final existing = _events[baseId]?[eventId];
    if (existing == null) throw StateError('missing event $eventId');
    _events[baseId]![eventId] = CalendarEventModel(
      id: existing.id,
      baseId: existing.baseId,
      title: input.title,
      startAt: input.startAt,
      endAt: input.endAt,
      allDay: input.allDay,
      notes: input.notes,
      createdBy: existing.createdBy,
      createdAt: existing.createdAt,
      updatedAt: _now(),
    );
    _emitAll();
  }

  @override
  Future<void> deleteEvent({
    required String baseId,
    required String eventId,
  }) async {
    _maybeThrow();
    _events[baseId]?.remove(eventId);
    _emitAll();
  }

  @override
  Future<CalendarSettings> getSettings({required String baseId}) async {
    _maybeThrow();
    settingsReads++;
    return _settings[baseId] ?? CalendarSettings.defaults;
  }

  @override
  Future<void> setSettings({
    required String baseId,
    required CalendarSettings settings,
  }) async {
    _maybeThrow();
    _settings[baseId] = settings;
  }

  Future<void> dispose() async {
    for (final c in List.of(_controllers)) {
      await c.close();
    }
  }
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final kOwner = 'owner'.uid;
final kMember = 'member'.uid;
final kStranger = 'stranger'.uid;

final kBase = Base(
  id: 'b1'.bid,
  name: 'Family',
  ownerUserId: kOwner,
  createdAt: DateTime.utc(2026, 1, 1),
);

/// Fixed "today" for window-dependent tests: 2026-09-27 12:00 local.
final kToday = DateTime(2026, 9, 27, 12);

EventInput inputAt(
  DateTime startLocal, {
  String title = 'Dinner',
  DateTime? end,
  bool allDay = false,
  String? notes,
}) =>
    EventInput(
      title: title,
      startAt: startLocal.toUtc(),
      endAt: end?.toUtc(),
      allDay: allDay,
      notes: notes,
    );

CalendarEvent eventBy(
  UserId author, {
  String id = 'e1',
  DateTime? start,
  String title = 'Dinner',
}) {
  final s = (start ?? kToday).toUtc();
  return CalendarEvent(
    id: id.eid,
    baseId: kBase.id,
    title: title,
    startAt: s,
    allDay: false,
    createdBy: author,
    createdAt: s,
    updatedAt: s,
  );
}
