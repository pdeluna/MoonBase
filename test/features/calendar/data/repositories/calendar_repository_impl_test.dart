import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/calendar/data/repositories/calendar_repository_impl.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_feed.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_freshness.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_settings.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_window.dart';

import '../../../../test_utils/fakes_calendar.dart';

void main() {
  late InMemoryCalendarDataSource ds;
  late CalendarRepositoryImpl repo;
  final range = CalendarWindow.defaults.resolve(kToday);

  setUp(() {
    ds = InMemoryCalendarDataSource(now: () => kToday.toUtc());
    repo = CalendarRepositoryImpl(source: ds);
  });

  tearDown(() => ds.dispose());

  test(
      'watchEvents maps fromCache → cached / live and keeps only in-range events',
      () async {
    ds.fromCache = true;
    final events = <CalendarFeed>[];
    final sub =
        repo.watchEvents(baseId: kBase.id, range: range).listen(events.add);
    await Future<void>.delayed(Duration.zero);
    expect(events.single.freshness, CalendarFreshness.cached);
    expect(events.single.events, isEmpty);

    ds.fromCache = false;
    await repo.createEvent(
        baseId: kBase.id, createdBy: kMember, input: inputAt(kToday));
    await repo.createEvent(
      baseId: kBase.id,
      createdBy: kMember,
      input: inputAt(DateTime(2027, 1, 1), title: 'far'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(events.last.freshness, CalendarFreshness.live);
    expect(events.last.events.map((e) => e.title), ['Dinner']);
    expect(events.last.isTruncated, isFalse);
    await sub.cancel();
  });

  test('watchEvents delivers thrown FirebaseException as a typed Failure',
      () async {
    ds.throwOn =
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    final completer = Completer<Object>();
    final sub = repo
        .watchEvents(baseId: kBase.id, range: range)
        .listen((_) {}, onError: completer.complete);
    final err = await completer.future;
    expect(err, isA<NetworkFailure>());
    await sub.cancel();
  });

  test('createEvent: FirebaseException → Left(mapException)', () async {
    ds.throwOn =
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');
    final r = await repo.createEvent(
        baseId: kBase.id, createdBy: kMember, input: inputAt(kToday));
    expect(r, isA<Left<Failure, dynamic>>());
    // Shared mapper types Firestore rules denials as PermissionDeniedFailure
    // (authored copy), same path calendar already uses for policy denials.
    expect(r.match((f) => f, (_) => null), isA<PermissionDeniedFailure>());

    ds.throwOn =
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    final r2 = await repo.deleteEvent(baseId: kBase.id, eventId: 'e0'.eid);
    expect(r2.match((f) => f, (_) => null), isA<NetworkFailure>());
  });

  test('getSettings returns defaults when missing; setSettings then reads back',
      () async {
    final missing = await repo.getSettings(baseId: kBase.id);
    expect(missing.match((f) => null, (s) => s), CalendarSettings.defaults);

    final custom = CalendarSettings.defaults.copyWith(
      window: const CalendarWindow(pastDays: 1, futureDays: 2),
    );
    expect((await repo.setSettings(baseId: kBase.id, settings: custom)).isRight,
        isTrue);
    expect(
        (await repo.getSettings(baseId: kBase.id)).match((f) => null, (s) => s),
        custom);
  });

  test(
      'getSettings: TimeoutException → NetworkTimeoutFailure (guardWithTimeout)',
      () async {
    ds.throwOn = TimeoutException('slow');
    final r = await repo.getSettings(baseId: kBase.id);
    expect(r.match((f) => f, (_) => null), isA<NetworkTimeoutFailure>());
  });
}
