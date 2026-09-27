import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/features/auth/domain/entities/user.dart';
import 'package:moonbase_skeleton/features/auth/presentation/providers/auth_providers.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/bases/presentation/providers/sidebar_providers.dart';
import 'package:moonbase_skeleton/features/calendar/data/repositories/calendar_repository_impl.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_feed.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_freshness.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_settings.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_window.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/event_creation_policy.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/controllers/calendar_controller.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/providers/calendar_home_vm_provider.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/viewmodels/calendar_home_vm.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/calendar_home_actions.dart';

import '../../../../test_utils/fakes_calendar.dart';

void main() {
  final owner = User(id: kOwner, nickname: 'Owner');
  final member = User(id: kMember, nickname: 'Member');

  ProviderContainer container({
    required AsyncValue<List<Base>> bases,
    Base? selected,
    User? user,
    InMemoryCalendarDataSource? ds,
  }) {
    final c = ProviderContainer(overrides: [
      basesListProvider.overrideWith((ref) => switch (bases) {
            AsyncData(:final value) => Future.value(value),
            AsyncError(:final error) => Future<List<Base>>.error(error),
            _ => Completer<List<Base>>().future,
          }),
      effectiveSelectedBaseProvider.overrideWithValue(selected),
      currentUserProvider.overrideWithValue(AsyncValue.data(user)),
      calendarClockProvider.overrideWithValue(() => kToday),
      calendarRepositoryProvider.overrideWithValue(
        CalendarRepositoryImpl(source: ds ?? InMemoryCalendarDataSource()),
      ),
    ]);
    addTearDown(c.dispose);
    // Keep the derived provider alive so the bases future actually starts.
    c.listen(calendarHomeVmProvider, (_, __) {}, fireImmediately: true);
    return c;
  }

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 5));

  group('basesState (bug B-e)', () {
    test('loading → loading, never empty', () async {
      final c = container(bases: const AsyncValue.loading(), user: member);
      await settle();
      final vm = c.read(calendarHomeVmProvider);
      expect(vm.basesState, CalendarBasesState.loading);
      expect(vm.hasBases, isFalse);
      expect(canShowAddEventFab(vm), isFalse);
    });

    test('error → unreachable', () async {
      final c = container(
        bases: AsyncValue.error(Exception('Network timeout'), StackTrace.empty),
        user: member,
      );
      await settle();
      expect(c.read(calendarHomeVmProvider).basesState,
          CalendarBasesState.unreachable);
    });

    test(
        'data([]) → empty with hasBases false; data([b]) + none selected → empty with hasBases true',
        () async {
      final c1 = container(bases: const AsyncValue.data([]), user: member);
      await settle();
      expect(
          c1.read(calendarHomeVmProvider).basesState, CalendarBasesState.empty);
      expect(c1.read(calendarHomeVmProvider).hasBases, isFalse);

      final c2 = container(bases: AsyncValue.data([kBase]), user: member);
      await settle();
      expect(
          c2.read(calendarHomeVmProvider).basesState, CalendarBasesState.empty);
      expect(c2.read(calendarHomeVmProvider).hasBases, isTrue);
    });

    test('data + selected → ready', () async {
      final c = container(
          bases: AsyncValue.data([kBase]), selected: kBase, user: member);
      await settle();
      expect(
          c.read(calendarHomeVmProvider).basesState, CalendarBasesState.ready);
    });
  });

  group('ready VM', () {
    test('isOwner / canAddEvent follow the policy; FAB rule', () async {
      final ds = InMemoryCalendarDataSource();
      await ds.setSettings(
        baseId: 'b1',
        settings: CalendarSettings.defaults
            .copyWith(eventCreation: EventCreationPolicy.ownerOnly),
      );

      final asMember = container(
          bases: AsyncValue.data([kBase]),
          selected: kBase,
          user: member,
          ds: ds);
      await asMember.read(calendarControllerProvider.notifier).load('b1');
      await settle();
      var vm = asMember.read(calendarHomeVmProvider);
      expect(vm.isOwner, isFalse);
      expect(vm.canAddEvent, isFalse);
      expect(canShowAddEventFab(vm), isFalse);

      final asOwner = container(
          bases: AsyncValue.data([kBase]),
          selected: kBase,
          user: owner,
          ds: ds);
      await asOwner.read(calendarControllerProvider.notifier).load('b1');
      await settle();
      vm = asOwner.read(calendarHomeVmProvider);
      expect(vm.isOwner, isTrue);
      expect(vm.canAddEvent, isTrue);
      expect(canShowAddEventFab(vm), isTrue);
    });

    test('feed for another base counts as loading (no stale sections)',
        () async {
      final c = container(
          bases: AsyncValue.data([kBase]), selected: kBase, user: member);
      await c.read(calendarControllerProvider.notifier).load('other');
      await settle();
      final vm = c.read(calendarHomeVmProvider);
      expect(vm.isFeedLoading, isTrue);
      expect(vm.sections, isEmpty);
    });

    test('sections, todayKey, freshness, canModify from a live feed', () async {
      final ds = InMemoryCalendarDataSource(now: () => kToday.toUtc());
      final c = container(
          bases: AsyncValue.data([kBase]),
          selected: kBase,
          user: member,
          ds: ds);
      await c.read(calendarControllerProvider.notifier).load('b1');
      await settle();
      final ctl = c.read(calendarControllerProvider.notifier);
      await ctl.create(
          base: kBase,
          requester: kOwner,
          input: inputAt(kToday, title: 'Owner today'));
      await ctl.create(
          base: kBase,
          requester: kMember,
          input:
              inputAt(kToday.add(const Duration(days: 2)), title: 'Mine +2'));
      await settle();

      final vm = c.read(calendarHomeVmProvider);
      expect(vm.isFeedLoading, isFalse);
      expect(vm.freshness, CalendarFreshness.live);
      expect(vm.todayKey, const DayKey(2026, 9, 27));
      expect(vm.sections.length, CalendarWindow.defaults.totalDays);
      expect(vm.sections.first.day, const DayKey(2026, 9, 20));
      expect(vm.sections.last.day, const DayKey(2026, 10, 27));
      final today = vm.sections.singleWhere((s) => s.isToday);
      expect(today.day, vm.todayKey);
      expect(today.events.single.title, 'Owner today');
      expect(vm.sections[9].events.single.title, 'Mine +2');
      expect(vm.eventCount, 2);
      expect(vm.canModify(today.events.single), isFalse,
          reason: 'member cannot modify owner event');
      expect(vm.canModify(vm.sections[9].events.single), isTrue);
    });
  });

  group('groupByDay', () {
    test('groups by device-local date and sorts within a day', () {
      final a = eventBy(kMember,
          id: 'a', start: DateTime(2026, 9, 27, 18), title: 'late');
      final b = eventBy(kMember,
          id: 'b', start: DateTime(2026, 9, 27, 9), title: 'early');
      final c = eventBy(kMember,
          id: 'c', start: DateTime(2026, 9, 26, 23, 59), title: 'yesterday');
      final feed =
          CalendarFeed(events: [b, a, c], freshness: CalendarFreshness.live);
      final sections = groupByDay(
          feed, const CalendarWindow(pastDays: 1, futureDays: 1), kToday);
      expect(sections.length, 3);
      expect(sections[0].events.map((e) => e.title), ['yesterday']);
      expect(sections[1].isToday, isTrue);
      expect(sections[1].events.map((e) => e.title), ['early', 'late']);
      expect(sections[2].isEmpty, isTrue);
    });
  });
}
