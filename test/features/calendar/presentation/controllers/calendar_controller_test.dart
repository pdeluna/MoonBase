import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/features/calendar/data/repositories/calendar_repository_impl.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_feed.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_freshness.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_settings.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_window.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/event_creation_policy.dart';
import 'package:moonbase_skeleton/features/calendar/domain/usecases/create_event.dart';
import 'package:moonbase_skeleton/features/calendar/domain/usecases/delete_event.dart';
import 'package:moonbase_skeleton/features/calendar/domain/usecases/get_calendar_settings.dart';
import 'package:moonbase_skeleton/features/calendar/domain/usecases/set_calendar_settings.dart';
import 'package:moonbase_skeleton/features/calendar/domain/usecases/update_event.dart';
import 'package:moonbase_skeleton/features/calendar/domain/usecases/watch_events.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/controllers/calendar_controller.dart';

import '../../../../test_utils/fakes_calendar.dart';

void main() {
  late InMemoryCalendarDataSource ds;
  late CalendarRepositoryImpl repo;
  late CalendarController c;

  CalendarFeed data(AsyncValue<CalendarFeed> av) => av.when(
        data: (v) => v,
        loading: () => fail('expected data, got loading'),
        error: (e, _) => fail('expected data, got error: $e'),
      );

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 5));

  setUp(() {
    ds = InMemoryCalendarDataSource(now: () => kToday.toUtc());
    repo = CalendarRepositoryImpl(source: ds);
    c = CalendarController(
      watchEvents: WatchEvents(repo),
      createEvent: CreateEvent(repo, now: () => kToday),
      updateEvent: UpdateEvent(repo, now: () => kToday),
      deleteEvent: DeleteEvent(repo),
      getSettings: GetCalendarSettings(repo),
      setSettings: SetCalendarSettings(repo),
      now: () => kToday,
    );
  });

  tearDown(() async {
    c.dispose();
    await ds.dispose();
  });

  test('load reads settings then streams; cached → live', () async {
    ds.fromCache = true;
    await c.load('b1');
    await settle();
    expect(c.state.baseId, 'b1');
    expect(c.state.settings, CalendarSettings.defaults);
    expect(ds.settingsReads, 1);
    expect(data(c.state.feed).freshness, CalendarFreshness.cached);

    ds.fromCache = false;
    final f =
        await c.create(base: kBase, requester: kMember, input: inputAt(kToday));
    expect(f, isNull);
    await settle();
    final feed = data(c.state.feed);
    expect(feed.freshness, CalendarFreshness.live);
    expect(feed.events.single.title, 'Dinner');
  });

  test('feed stays loading until the first emission', () async {
    // Settings resolve immediately; the fake stream emits on listen, so
    // check state right after load() returns but before the microtask runs.
    final future = c.load('b1');
    expect(c.state.feed.isLoading, isTrue);
    await future;
    await settle();
    expect(c.state.feed.hasValue, isTrue);
  });

  test('base switch cancels the previous subscription', () async {
    await c.load('b1');
    await settle();
    expect(ds.activeListeners, 1);
    await c.load('b2');
    await settle();
    expect(ds.activeListeners, 1);
    expect(c.state.baseId, 'b2');

    // An event in b1 must not reach the b2 feed.
    await repo.createEvent(
        baseId: kBase.id, createdBy: kMember, input: inputAt(kToday));
    await settle();
    expect(data(c.state.feed).events, isEmpty);
  });

  test('clear cancels and resets', () async {
    await c.load('b1');
    await settle();
    c.clear();
    expect(ds.activeListeners, 0);
    expect(c.state.baseId, isNull);
    expect(c.state.feed.isLoading, isTrue);
  });

  test('stream error → AsyncValue.error with a typed Failure', () async {
    ds.throwOn = StateError('boom');
    await c.load('b1');
    await settle();
    // getSettings threw too → defaults + settingsFailure recorded.
    expect(c.state.settingsFailure, isA<CacheFailure>());
    expect(c.state.settings, CalendarSettings.defaults);
    expect(c.state.feed.hasError, isTrue);
    expect(c.state.feed.error, isA<CacheFailure>());
  });

  test('mutations return Failure? and never throw', () async {
    await c.load('b1');
    await settle();

    final denied = await c.create(
      base: kBase,
      requester: kStranger,
      input: inputAt(kToday, title: ''),
    );
    expect(denied, isA<ValidationFailure>());

    ds.throwOn = StateError('down');
    final down =
        await c.create(base: kBase, requester: kMember, input: inputAt(kToday));
    expect(down, isA<CacheFailure>());
    ds.throwOn = null;

    expect(
        await c.create(base: kBase, requester: kMember, input: inputAt(kToday)),
        isNull);
    await settle();
    final ev = data(c.state.feed).events.single;

    expect(
      await c.update(
          base: kBase,
          requester: kStranger,
          existing: ev,
          input: inputAt(kToday)),
      isA<PermissionDeniedFailure>(),
    );
    expect(
      await c.update(
          base: kBase,
          requester: kMember,
          existing: ev,
          input: inputAt(kToday, title: 'Renamed')),
      isNull,
    );
    await settle();
    expect(data(c.state.feed).events.single.title, 'Renamed');

    expect(await c.delete(base: kBase, requester: kOwner, event: ev), isNull);
    await settle();
    expect(data(c.state.feed).events, isEmpty);
  });

  test('create under ownerOnly uses the loaded settings', () async {
    await ds.setSettings(
      baseId: 'b1',
      settings: CalendarSettings.defaults
          .copyWith(eventCreation: EventCreationPolicy.ownerOnly),
    );
    await c.load('b1');
    await settle();
    expect(c.state.settings.eventCreation, EventCreationPolicy.ownerOnly);
    expect(
      await c.create(base: kBase, requester: kMember, input: inputAt(kToday)),
      isA<PermissionDeniedFailure>(),
    );
    expect(
        await c.create(base: kBase, requester: kOwner, input: inputAt(kToday)),
        isNull);
  });

  test(
      'saveSettings by owner adopts clamped settings and re-subscribes with the new window',
      () async {
    await c.load('b1');
    await settle();
    await c.create(
        base: kBase,
        requester: kMember,
        input: inputAt(kToday.add(const Duration(days: 20))));
    await settle();
    expect(data(c.state.feed).events.length, 1);

    final f = await c.saveSettings(
      base: kBase,
      requester: kOwner,
      settings: const CalendarSettings(
        window: CalendarWindow(pastDays: 0, futureDays: 7),
        eventCreation: EventCreationPolicy.allMembers,
      ),
    );
    expect(f, isNull);
    await settle();
    expect(c.state.settings.window,
        const CalendarWindow(pastDays: 0, futureDays: 7));
    expect(ds.activeListeners, 1);
    expect(data(c.state.feed).events, isEmpty,
        reason: '20-day event now outside window');

    final denied = await c.saveSettings(
      base: kBase,
      requester: kMember,
      settings: CalendarSettings.defaults,
    );
    expect(denied, isA<PermissionDeniedFailure>());
  });
}
