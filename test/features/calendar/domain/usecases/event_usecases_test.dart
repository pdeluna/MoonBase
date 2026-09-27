import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/validators.dart';
import 'package:moonbase_skeleton/features/calendar/data/repositories/calendar_repository_impl.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_event.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_permissions.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_settings.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_window.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/event_creation_policy.dart';
import 'package:moonbase_skeleton/features/calendar/domain/usecases/create_event.dart';
import 'package:moonbase_skeleton/features/calendar/domain/usecases/delete_event.dart';
import 'package:moonbase_skeleton/features/calendar/domain/usecases/set_calendar_settings.dart';
import 'package:moonbase_skeleton/features/calendar/domain/usecases/update_event.dart';

import '../../../../test_utils/fakes_calendar.dart';

void main() {
  late InMemoryCalendarDataSource ds;
  late CalendarRepositoryImpl repo;

  setUp(() {
    ds = InMemoryCalendarDataSource(now: () => kToday.toUtc());
    repo = CalendarRepositoryImpl(source: ds);
  });

  Failure leftOf<T>(Either<Failure, T> e) =>
      e.match((f) => f, (_) => fail('expected Left, got Right'));
  T rightOf<T>(Either<Failure, T> e) =>
      e.match((f) => fail('expected Right, got $f'), (r) => r);

  CreateEventParams create({
    required String title,
    DateTime? start,
    DateTime? end,
    String? notes,
    CalendarSettings settings = CalendarSettings.defaults,
    UserId? requester,
  }) =>
      CreateEventParams(
        base: kBase,
        requester: requester ?? kMember,
        settings: settings,
        input: inputAt(start ?? kToday, title: title, end: end, notes: notes),
      );

  group('CreateEvent — validation', () {
    late CreateEvent uc;
    setUp(() => uc = CreateEvent(repo, now: () => kToday));

    test('happy path trims title and persists', () async {
      final r = rightOf(await uc(create(title: '  Dinner  ')));
      expect(r.title, 'Dinner');
      expect(r.createdBy, kMember);
      expect(r.startAt.isUtc, isTrue);
      expect(ds.eventsFor('b1').length, 1);
    });

    test('blank title → ValidationFailure', () async {
      expect(leftOf(await uc(create(title: '   '))), isA<ValidationFailure>());
      expect(ds.eventsFor('b1'), isEmpty);
    });

    test('81-char title → ValidationFailure; 80 ok', () async {
      expect(
        leftOf(await uc(create(title: 'x' * (kEventTitleMaxLen + 1)))),
        isA<ValidationFailure>(),
      );
      rightOf(await uc(create(title: 'x' * kEventTitleMaxLen)));
    });

    test('501-char notes → ValidationFailure; blank notes collapse to null',
        () async {
      expect(
        leftOf(await uc(create(title: 'a', notes: 'n' * (kEventNotesMaxLen + 1)))),
        isA<ValidationFailure>(),
      );
      final r = rightOf(await uc(create(title: 'a', notes: '   ')));
      expect(r.notes, isNull);
    });

    test('end before start → ValidationFailure; end == start ok', () async {
      final start = kToday;
      expect(
        leftOf(await uc(create(
          title: 'a',
          start: start,
          end: start.subtract(const Duration(minutes: 1)),
        ))),
        isA<ValidationFailure>(),
      );
      rightOf(await uc(create(title: 'a', start: start, end: start)));
    });

    test('startAt outside the window → ValidationFailure (both edges)', () async {
      // defaults: 7 back / 30 ahead around 2026-09-27
      expect(
        leftOf(await uc(create(title: 'a', start: DateTime(2026, 9, 19, 23, 59)))),
        isA<ValidationFailure>(),
      );
      expect(
        leftOf(await uc(create(title: 'a', start: DateTime(2026, 10, 28)))),
        isA<ValidationFailure>(),
      );
      rightOf(await uc(create(title: 'a', start: DateTime(2026, 9, 20))));
      rightOf(await uc(create(title: 'a', start: DateTime(2026, 10, 27, 23, 59))));
    });
  });

  group('CreateEvent — creation policy', () {
    final ownerOnly = CalendarSettings.defaults
        .copyWith(eventCreation: EventCreationPolicy.ownerOnly);

    test('member denied under ownerOnly → PermissionDeniedFailure, no write',
        () async {
      final uc = CreateEvent(repo, now: () => kToday);
      final f = leftOf(await uc(create(title: 'a', settings: ownerOnly)));
      expect(f, isA<PermissionDeniedFailure>());
      expect(ds.eventsFor('b1'), isEmpty);
    });

    test('owner allowed under ownerOnly', () async {
      final uc = CreateEvent(repo, now: () => kToday);
      rightOf(await uc(create(title: 'a', settings: ownerOnly, requester: kOwner)));
    });

    test('data-source throw surfaces as Left, never throws', () async {
      ds.throwOn = StateError('boom');
      final uc = CreateEvent(repo, now: () => kToday);
      final f = leftOf(await uc(create(title: 'a')));
      expect(f, isA<CacheFailure>());
    });
  });

  group('UpdateEvent / DeleteEvent — author-or-owner', () {
    late CalendarEvent memberEvent;
    late CalendarEvent ownerEvent;

    setUp(() async {
      final c = CreateEvent(repo, now: () => kToday);
      memberEvent = rightOf(await c(create(title: 'Mine')));
      ownerEvent = rightOf(await c(create(title: 'Owner', requester: kOwner)));
    });

    UpdateEventParams upd(CalendarEvent e, UserId requester, {String title = 'New'}) =>
        UpdateEventParams(
          base: kBase,
          requester: requester,
          existing: e,
          window: CalendarWindow.defaults,
          input: inputAt(kToday, title: title),
        );

    test('canModifyEvent: author yes, owner yes, other member no', () {
      expect(canModifyEvent(event: memberEvent, user: kMember, base: kBase), isTrue);
      expect(canModifyEvent(event: memberEvent, user: kOwner, base: kBase), isTrue);
      expect(canModifyEvent(event: ownerEvent, user: kMember, base: kBase), isFalse);
      expect(canModifyEvent(event: memberEvent, user: kStranger, base: kBase), isFalse);
    });

    test('author update ok and returns merged entity', () async {
      final uc = UpdateEvent(repo, now: () => kToday.add(const Duration(hours: 1)));
      final r = rightOf(await uc(upd(memberEvent, kMember, title: 'Renamed')));
      expect(r.id, memberEvent.id);
      expect(r.title, 'Renamed');
      expect(r.createdBy, kMember);
      expect(r.updatedAt.isAfter(memberEvent.updatedAt), isTrue);
      expect(ds.eventsFor('b1').firstWhere((e) => e.id == 'e0').title, 'Renamed');
    });

    test('owner may update a member event; member may not update owner event',
        () async {
      final uc = UpdateEvent(repo, now: () => kToday);
      rightOf(await uc(upd(memberEvent, kOwner)));
      expect(leftOf(await uc(upd(ownerEvent, kMember))), isA<PermissionDeniedFailure>());
    });

    test('update still validates (81-char title)', () async {
      final uc = UpdateEvent(repo, now: () => kToday);
      expect(
        leftOf(await uc(upd(memberEvent, kMember, title: 'x' * 81))),
        isA<ValidationFailure>(),
      );
    });

    test('delete: author ok, owner ok, other member denied', () async {
      final del = DeleteEvent(repo);
      expect(
        leftOf(await del(DeleteEventParams(base: kBase, requester: kMember, event: ownerEvent))),
        isA<PermissionDeniedFailure>(),
      );
      rightOf(await del(DeleteEventParams(base: kBase, requester: kMember, event: memberEvent)));
      rightOf(await del(DeleteEventParams(base: kBase, requester: kOwner, event: ownerEvent)));
      expect(ds.eventsFor('b1'), isEmpty);
    });
  });

  group('SetCalendarSettings', () {
    test('member → PermissionDeniedFailure, nothing written', () async {
      final uc = SetCalendarSettings(repo);
      final f = leftOf(await uc(SetCalendarSettingsParams(
        base: kBase,
        requester: kMember,
        settings: CalendarSettings.defaults,
      )));
      expect(f, isA<PermissionDeniedFailure>());
      expect(ds.settingsReads, 0);
      expect(rightOf(await repo.getSettings(baseId: kBase.id)), CalendarSettings.defaults);
    });

    test('owner write clamps window to 0–365 and returns the clamped copy',
        () async {
      final uc = SetCalendarSettings(repo);
      final r = rightOf(await uc(SetCalendarSettingsParams(
        base: kBase,
        requester: kOwner,
        settings: const CalendarSettings(
          window: CalendarWindow(pastDays: -1, futureDays: 400),
          eventCreation: EventCreationPolicy.ownerOnly,
        ),
      )));
      expect(r.window, const CalendarWindow(pastDays: 0, futureDays: 365));
      expect(r.eventCreation, EventCreationPolicy.ownerOnly);
      expect(rightOf(await repo.getSettings(baseId: kBase.id)), r);
    });
  });
}
