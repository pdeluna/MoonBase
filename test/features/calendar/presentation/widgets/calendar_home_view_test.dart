import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/core/di/providers.dart';
import 'package:moonbase_skeleton/features/auth/domain/entities/user.dart';
import 'package:moonbase_skeleton/features/auth/presentation/providers/auth_providers.dart';
import 'package:moonbase_skeleton/features/auth/presentation/providers/member_presentation_provider.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/bases/presentation/providers/sidebar_providers.dart';
import 'package:moonbase_skeleton/features/calendar/data/repositories/calendar_repository_impl.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_settings.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/event_creation_policy.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/providers/calendar_home_vm_provider.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/bases_unreachable_view.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/cached_events_banner.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/viewmodels/calendar_home_vm.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/calendar_day_sheet.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/calendar_grid.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/calendar_home_view.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/calendar_loading_skeleton.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/event_detail_sheet.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/lunar_candy.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/no_base_view.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/stories_strip.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/window_label.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../test_utils/fakes_calendar.dart';

void main() {
  final owner = User(id: kOwner, nickname: 'Owner');
  final member = User(id: kMember, nickname: 'Member');

  late InMemoryCalendarDataSource ds;
  late int basesLoads;

  setUp(() {
    ds = InMemoryCalendarDataSource(now: () => kToday.toUtc());
    basesLoads = 0;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() => ds.dispose());

  Future<void> pumpHome(
    WidgetTester tester, {
    required Future<List<Base>> Function() bases,
    Base? selected,
    User? user,
    bool disableAnimations = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          basesListProvider.overrideWith((ref) {
            basesLoads++;
            return bases();
          }),
          effectiveSelectedBaseProvider.overrideWithValue(selected),
          currentUserProvider.overrideWithValue(AsyncValue.data(user)),
          calendarClockProvider.overrideWithValue(() => kToday),
          calendarRepositoryProvider.overrideWithValue(
            CalendarRepositoryImpl(source: ds),
          ),
          memberPresentationProvider.overrideWith(
            (ref, uid) => MemberPresentation(
              nickname: uid == kOwner.value ? 'Owner' : 'Member',
              nameColor: Colors.teal,
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en', 'US'),
          builder:
              disableAnimations
                  ? (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(disableAnimations: true),
                    child: child ?? const SizedBox.shrink(),
                  )
                  : null,
          home: const Scaffold(body: CalendarHomeView()),
        ),
      ),
    );
  }

  group('B-e no-base states', () {
    testWidgets('loading → skeleton, never the create prompt', (tester) async {
      final never = Completer<List<Base>>();
      await pumpHome(tester, bases: () => never.future, user: member);
      await tester.pump();
      expect(find.byType(CalendarLoadingSkeleton), findsOneWidget);
      expect(find.byType(StoriesStrip), findsNothing);
      expect(find.text(NoBaseView.noBasesTitle), findsNothing);
      expect(find.text(BasesUnreachableView.copy), findsNothing);
    });

    testWidgets('error → "Can\'t reach MoonBase" + Retry re-fetches bases', (
      tester,
    ) async {
      await pumpHome(
        tester,
        bases: () => Future<List<Base>>.error(Exception('Network timeout')),
        user: member,
      );
      await tester.pump();
      expect(find.text(BasesUnreachableView.copy), findsOneWidget);
      expect(find.text(NoBaseView.noBasesTitle), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);
      expect(basesLoads, 1);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(basesLoads, 2);
    });

    testWidgets('data([]) → create/join prompt', (tester) async {
      await pumpHome(tester, bases: () async => [], user: member);
      await tester.pump();
      expect(find.text(NoBaseView.noBasesTitle), findsOneWidget);
      expect(find.text('Create Base'), findsOneWidget);
      expect(find.text('Join Base'), findsOneWidget);
    });

    testWidgets('bases exist but none selected → pick-a-base copy', (
      tester,
    ) async {
      await pumpHome(tester, bases: () async => [kBase], user: member);
      await tester.pump();
      expect(find.text(NoBaseView.pickTitle), findsOneWidget);
    });
  });

  group('ready', () {
    testWidgets('empty week grid; owner sees Settings, member does not', (
      tester,
    ) async {
      await pumpHome(
        tester,
        bases: () async => [kBase],
        selected: kBase,
        user: member,
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Nothing planned'), findsNothing);
      expect(find.text('Nothing planned in this window'), findsNothing);
      expect(find.text('Add event'), findsNothing);
      expect(find.byType(StoriesStrip), findsOneWidget);
      expect(find.text('Month'), findsOneWidget);
      expect(find.byKey(WindowLabel.gearKey), findsNothing);
      expect(find.text('Settings'), findsNothing);
      expect(find.textContaining('7 days back'), findsOneWidget);
      expect(find.text('27'), findsOneWidget);

      await pumpHome(
        tester,
        bases: () async => [kBase],
        selected: kBase,
        user: owner,
      );
      await tester.pump();
      await tester.pump();
      expect(find.byKey(WindowLabel.gearKey), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Calendar settings'), findsOneWidget);
      expect(
        find.widgetWithText(ChoiceChip, 'Month'),
        findsOneWidget,
        reason: 'the query preset stays Month; the expander is separate',
      );
      expect(find.byKey(CalendarGridHeader.spanKey), findsOneWidget);
    });

    testWidgets('member under ownerOnly: no Add event affordance', (
      tester,
    ) async {
      await ds.setSettings(
        baseId: 'b1',
        settings: CalendarSettings.defaults.copyWith(
          eventCreation: EventCreationPolicy.ownerOnly,
        ),
      );
      await pumpHome(
        tester,
        bases: () async => [kBase],
        selected: kBase,
        user: member,
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Nothing planned'), findsNothing);
      expect(find.text('Add event'), findsNothing);
      expect(find.byType(CalendarGrid), findsOneWidget);
    });

    testWidgets('week chips open the detail sheet; empty days stay blank', (
      tester,
    ) async {
      await ds.createEvent(
        baseId: 'b1',
        createdBy: kOwner.value,
        input: inputAt(kToday, title: 'Owner dinner', notes: 'Bring dessert'),
      );
      await ds.createEvent(
        baseId: 'b1',
        createdBy: kMember.value,
        input: inputAt(kToday.add(const Duration(days: 1)), title: 'My lunch'),
      );
      await pumpHome(
        tester,
        bases: () async => [kBase],
        selected: kBase,
        user: member,
      );
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Today'), findsNothing);
      expect(find.text('Nothing planned'), findsNothing);
      expect(find.text('Owner dinner'), findsOneWidget);
      expect(find.text('My lunch'), findsOneWidget);
      expect(find.text('Owner'), findsNothing);
      expect(find.byType(CachedEventsBanner), findsOneWidget);
      expect(
        find.text(CachedEventsBanner.copy),
        findsNothing,
        reason: 'live feed',
      );

      // Owner's event → read-only for a member.
      await tester.tap(find.text('Owner dinner'));
      await tester.pumpAndSettle();
      expect(find.byType(EventDetailSheet), findsOneWidget);
      expect(find.text('Added by Owner'), findsOneWidget);
      expect(find.text('Bring dessert'), findsOneWidget);
      expect(find.byKey(EventDetailSheet.editKey), findsNothing);
      expect(find.byKey(EventDetailSheet.deleteKey), findsNothing);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Own event → edit + delete.
      await tester.tap(find.text('My lunch'));
      await tester.pumpAndSettle();
      expect(find.byKey(EventDetailSheet.editKey), findsOneWidget);
      expect(find.byKey(EventDetailSheet.deleteKey), findsOneWidget);
    });

    testWidgets('several events on a day open a sheet of cards', (
      tester,
    ) async {
      await ds.createEvent(
        baseId: 'b1',
        createdBy: kOwner.value,
        input: inputAt(kToday, title: 'Owner dinner'),
      );
      await ds.createEvent(
        baseId: 'b1',
        createdBy: kMember.value,
        input: inputAt(
          kToday.add(const Duration(hours: 2)),
          title: 'Owner dessert',
        ),
      );
      await pumpHome(
        tester,
        bases: () async => [kBase],
        selected: kBase,
        user: member,
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Owner dinner'), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
      expect(find.text('Owner dessert'), findsNothing);

      await tester.tap(find.text('Owner dinner'));
      await tester.pumpAndSettle();
      expect(find.byKey(CalendarDaySheet.sheetKey), findsOneWidget);
      expect(find.text('Owner dessert'), findsOneWidget);

      await tester.tap(find.text('Owner dessert'));
      await tester.pumpAndSettle();
      expect(find.byType(EventDetailSheet), findsOneWidget);
    });

    testWidgets(
      'month fills in with dots; days outside the window match empty days',
      (tester) async {
        await ds.createEvent(
          baseId: 'b1',
          createdBy: kOwner.value,
          input: inputAt(kToday, title: 'Owner dinner'),
        );
        await pumpHome(
          tester,
          bases: () async => [kBase],
          selected: kBase,
          user: member,
        );
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text('Month'));
        await tester.pumpAndSettle();

        expect(find.text('Week'), findsOneWidget);
        expect(find.textContaining('7 days back'), findsOneWidget);
        expect(find.text('September 2026'), findsOneWidget);
        expect(
          tester.getSize(find.byKey(CalendarHomeView.storiesSlotKey)).height,
          0,
        );
        expect(find.text('Owner dinner'), findsNothing);
        expect(
          find.byKey(CalendarGrid.dotKey(const DayKey(2026, 9, 27), 0)),
          findsOneWidget,
        );

        const outside = DayKey(2026, 9, 1);
        const loadedEmpty = DayKey(2026, 9, 20);
        expect(find.byKey(CalendarGrid.cellKey(outside)), findsOneWidget);
        expect(_cellFill(tester, outside), _cellFill(tester, loadedEmpty));
        expect(_cellFill(tester, outside), LunarCandy.cellLight);
        expect(_cellFill(tester, const DayKey(2026, 9, 27)), LunarCandy.today);

        await tester.tap(find.byKey(CalendarGrid.cellKey(outside)));
        await tester.pumpAndSettle();
        expect(find.byType(EventDetailSheet), findsNothing);
        expect(find.byType(CalendarDaySheet), findsNothing);

        await tester.tap(
          find.byKey(CalendarGrid.cellKey(const DayKey(2026, 9, 27))),
        );
        await tester.pumpAndSettle();
        expect(find.byType(EventDetailSheet), findsOneWidget);
      },
    );

    testWidgets('a fourth event replaces the third dot with +', (tester) async {
      for (var i = 0; i < 4; i++) {
        await ds.createEvent(
          baseId: 'b1',
          createdBy: kOwner.value,
          input: inputAt(kToday.add(Duration(hours: i)), title: 'Event $i'),
        );
      }
      await pumpHome(
        tester,
        bases: () async => [kBase],
        selected: kBase,
        user: member,
      );
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();

      const today = DayKey(2026, 9, 27);
      expect(find.byKey(CalendarGrid.dotKey(today, 0)), findsOneWidget);
      expect(find.byKey(CalendarGrid.dotKey(today, 1)), findsOneWidget);
      expect(find.byKey(CalendarGrid.dotKey(today, 2)), findsNothing);
      expect(find.byKey(CalendarGrid.moreKey(today)), findsOneWidget);
      expect(find.text('Event 0'), findsNothing);
    });

    testWidgets('reduced motion snaps the stories strip shut', (tester) async {
      await pumpHome(
        tester,
        bases: () async => [kBase],
        selected: kBase,
        user: member,
        disableAnimations: true,
      );
      await tester.pump();
      await tester.pump();
      expect(
        tester.getSize(find.byKey(CalendarHomeView.storiesSlotKey)).height,
        greaterThan(0),
      );
      await tester.tap(find.text('Month'));
      await tester.pump();
      expect(
        tester.getSize(find.byKey(CalendarHomeView.storiesSlotKey)).height,
        0,
      );
    });

    testWidgets('feed error keeps the stories strip and hides day cells', (
      tester,
    ) async {
      ds.throwOn = Exception('offline');
      await pumpHome(
        tester,
        bases: () async => [kBase],
        selected: kBase,
        user: member,
      );
      await tester.pump();
      await tester.pump();
      expect(find.text(CalendarHomeView.feedErrorCopy), findsOneWidget);
      expect(find.byType(StoriesStrip), findsOneWidget);
      expect(find.byKey(CalendarGrid.gridKey), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('cached feed shows the cached banner after the delay', (
      tester,
    ) async {
      ds.fromCache = true;
      await ds.createEvent(
        baseId: 'b1',
        createdBy: kOwner.value,
        input: inputAt(kToday),
      );
      await pumpHome(
        tester,
        bases: () async => [kBase],
        selected: kBase,
        user: member,
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(CachedEventsBanner.delay);
      expect(find.text(CachedEventsBanner.copy), findsOneWidget);
    });
  });
}

Color _cellFill(WidgetTester tester, DayKey day) {
  final boxes = tester.widgetList<DecoratedBox>(
    find.descendant(
      of: find.byKey(CalendarGrid.cellKey(day)),
      matching: find.byType(DecoratedBox),
    ),
  );
  final decoration = boxes.first.decoration as BoxDecoration;
  return decoration.color!;
}
