import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/core/di/providers.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/auth/domain/entities/user.dart';
import 'package:moonbase_skeleton/features/auth/presentation/providers/auth_providers.dart';
import 'package:moonbase_skeleton/features/auth/presentation/providers/member_presentation_provider.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/bases/presentation/providers/sidebar_providers.dart';
import 'package:moonbase_skeleton/features/calendar/data/repositories/calendar_repository_impl.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_settings.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/event_creation_policy.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/providers/stories_seam.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/bases_unreachable_view.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/cached_events_banner.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/viewmodels/calendar_home_vm.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/calendar_grid.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/day_agenda.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/calendar_home_view.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/calendar_loading_skeleton.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/calendar_tokens.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/event_detail_sheet.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/date_heading.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/no_base_view.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/stories_heading.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/shared_today_section.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/week_strip.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/window_label.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_ref.dart';
import 'package:moonbase_skeleton/features/media/domain/entities/media_type.dart';
import 'package:moonbase_skeleton/features/media/domain/repositories/media_storage.dart';
import 'package:moonbase_skeleton/features/media/presentation/providers/media_providers.dart';
import 'package:moonbase_skeleton/features/media/presentation/widgets/media_tile.dart';
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
    AsyncValue<StoriesHeadingData> stories =
        const AsyncValue.data(StoriesHeadingData.empty),
    Override? storiesOverride,
    Set<DayKey> memoryDays = const {},
    void Function(BuildContext context)? onCapture,
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
          storiesOverride ?? storiesHeadingProvider.overrideWithValue(stories),
          memoryDaysProvider.overrideWithValue(memoryDays),
          openStoryCaptureProvider.overrideWithValue(onCapture ?? (_) {}),
          mediaStorageProvider.overrideWithValue(_ThrowingMediaStorage()),
        ],
        child: MaterialApp(
          locale: const Locale('en', 'US'),
          builder: disableAnimations
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
      expect(find.byType(DateHeading), findsNothing);
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
      expect(find.text(DayAgenda.emptyCopy), findsOneWidget);
      expect(find.byKey(DayAgenda.addKey), findsOneWidget);
      expect(find.text('ON THE CALENDAR'), findsOneWidget);
      expect(find.byType(DateHeading), findsOneWidget);
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
      expect(find.text(DayAgenda.emptyCopy), findsOneWidget);
      expect(find.text('Add event'), findsNothing);
      expect(find.byType(WeekStrip), findsOneWidget);
    });

    testWidgets('the agenda opens the detail sheet for the selected day', (
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
      expect(find.text('My lunch'), findsNothing);
      expect(find.text('Owner'), findsOneWidget);
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

      await tester.tap(find.byKey(WeekStrip.dayKey(const DayKey(2026, 9, 28))));
      await tester.pump();
      expect(find.text('ON THE CALENDAR · MON, SEP 28'), findsOneWidget);
      expect(find.text('My lunch'), findsOneWidget);
      expect(find.text('Owner dinner'), findsNothing);

      // Own event → edit + delete.
      await tester.tap(find.text('My lunch'));
      await tester.pumpAndSettle();
      expect(find.byKey(EventDetailSheet.editKey), findsOneWidget);
      expect(find.byKey(EventDetailSheet.deleteKey), findsOneWidget);
    });

    testWidgets('the agenda lists every event and a card opens the detail', (
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
      expect(find.text('+1'), findsNothing);
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
        const today = DayKey(2026, 9, 27);
        expect(
          find.descendant(
            of: find.byKey(CalendarGrid.cellKey(today)),
            matching: find.text('Owner dinner'),
          ),
          findsNothing,
        );
        expect(find.text('Owner dinner'), findsOneWidget);
        expect(find.byKey(CalendarGrid.dotKey(today, 0)), findsOneWidget);

        const outside = DayKey(2026, 9, 1);
        const loadedEmpty = DayKey(2026, 9, 20);
        expect(find.byKey(CalendarGrid.cellKey(outside)), findsOneWidget);
        expect(_cellFill(tester, outside), _cellFill(tester, loadedEmpty));
        expect(_cellFill(tester, outside), CalendarTokens.cardLight);
        expect(_cellFill(tester, today), CalendarTokens.accent);
        expect(
          tester.getSize(find.byKey(CalendarGrid.cellKey(outside))).height,
          CalendarGrid.rowHeight,
        );

        await tester.tap(find.byKey(CalendarGrid.cellKey(outside)));
        await tester.pumpAndSettle();
        expect(find.byType(EventDetailSheet), findsNothing);
        expect(find.text('Owner dinner'), findsOneWidget);

        await tester.tap(find.byKey(CalendarGrid.cellKey(loadedEmpty)));
        await tester.pumpAndSettle();
        expect(find.byType(EventDetailSheet), findsNothing);
        expect(find.text('ON THE CALENDAR · SUN, SEP 20'), findsOneWidget);
        expect(find.text(DayAgenda.emptyCopy), findsOneWidget);
        expect(find.text('Owner dinner'), findsNothing);
        expect(
          _cellDecoration(tester, loadedEmpty).border,
          Border.all(color: CalendarTokens.accent, width: 1.5),
        );

        await tester.tap(find.byKey(CalendarGrid.cellKey(today)));
        await tester.pumpAndSettle();
        expect(find.byType(EventDetailSheet), findsNothing);
        expect(find.text('Owner dinner'), findsOneWidget);
        expect(_cellDecoration(tester, today).border, isNull);

        await tester.ensureVisible(find.text('Owner dinner'));
        await tester.tap(find.text('Owner dinner'));
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
      expect(
        find.descendant(
          of: find.byKey(CalendarGrid.cellKey(today)),
          matching: find.text('Event 0'),
        ),
        findsNothing,
      );
      expect(find.text('Event 0'), findsOneWidget);
    });

    testWidgets('reduced motion snaps the stories strip shut', (tester) async {
      await pumpHome(
        tester,
        bases: () async => [kBase],
        selected: kBase,
        user: member,
        disableAnimations: true,
        stories: AsyncValue.data(
          StoriesHeadingData(
            authors: [
              StoriesHeadingAuthor(userId: kOwner, opened: false),
            ],
          ),
        ),
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
      expect(find.byType(DateHeading), findsOneWidget);
      expect(find.byKey(CalendarGrid.gridKey), findsNothing);
      expect(find.byKey(WeekStrip.stripKey), findsNothing);
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

  group('stories heading', () {
    Future<void> pumpReady(
      WidgetTester tester, {
      AsyncValue<StoriesHeadingData> stories =
          const AsyncValue.data(StoriesHeadingData.empty),
      Override? storiesOverride,
      void Function(BuildContext context)? onCapture,
    }) {
      return pumpHome(
        tester,
        bases: () async => [kBase],
        selected: kBase,
        user: member,
        stories: stories,
        storiesOverride: storiesOverride,
        onCapture: onCapture,
      );
    }

    testWidgets('loading draws three skeleton circles at the row height', (
      tester,
    ) async {
      await pumpReady(tester, stories: const AsyncValue.loading());
      await tester.pump();

      expect(find.byKey(StoriesHeading.skeletonDotKey(0)), findsOneWidget);
      expect(find.byKey(StoriesHeading.skeletonDotKey(1)), findsOneWidget);
      expect(find.byKey(StoriesHeading.skeletonDotKey(2)), findsOneWidget);
      expect(find.byKey(StoriesHeading.skeletonDotKey(3)), findsNothing);
      expect(
        tester.getSize(find.byKey(StoriesHeading.skeletonDotKey(0))),
        const Size.square(StoriesHeading.skeletonSize),
      );
      expect(
        tester.getSize(find.byKey(StoriesHeading.skeletonKey)).height,
        StoriesHeading.rowHeight,
      );
    });

    testWidgets('error keeps the calendar and Retry rebuilds the provider', (
      tester,
    ) async {
      var builds = 0;
      await pumpReady(
        tester,
        storiesOverride: storiesHeadingProvider.overrideWith((ref) {
          builds++;
          return AsyncValue<StoriesHeadingData>.error(
            StateError('stories'),
            StackTrace.empty,
          );
        }),
      );
      await tester.pump();
      await tester.pump();

      expect(builds, 1);
      expect(find.text(StoriesHeading.errorCopy), findsOneWidget);
      final retry = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Retry'),
      );
      expect(retry.style?.foregroundColor?.resolve({}), CalendarTokens.accent);
      expect(
        retry.style?.textStyle?.resolve({})?.fontWeight,
        FontWeight.w600,
      );
      expect(find.text('Month'), findsOneWidget);
      expect(find.text('27'), findsOneWidget);

      await tester.tap(find.byKey(StoriesHeading.retryKey));
      await tester.pump();
      expect(builds, 2);
    });

    testWidgets('empty stories leave the date heading and hide the row', (
      tester,
    ) async {
      await pumpReady(tester);
      await tester.pump();
      await tester.pump();

      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('Sun, Sep 27'), findsOneWidget);
      expect(find.byKey(DateHeading.shareKey), findsOneWidget);
      expect(find.byKey(StoriesHeading.rowKey), findsNothing);
    });

    testWidgets('bubbles are newest first, ringed only when unopened', (
      tester,
    ) async {
      await pumpReady(
        tester,
        stories: AsyncValue.data(
          StoriesHeadingData(
            authors: [
              StoriesHeadingAuthor(userId: kOwner, opened: false),
              StoriesHeadingAuthor(userId: kMember, opened: true),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final owner = find.byKey(StoriesHeading.bubbleKey(kOwner.value));
      final memberBubble = find.byKey(StoriesHeading.bubbleKey(kMember.value));
      expect(
        tester.getTopLeft(owner).dx,
        lessThan(tester.getTopLeft(memberBubble).dx),
      );
      expect(find.byKey(StoriesHeading.ringKey(kOwner.value)), findsOneWidget);
      expect(find.byKey(StoriesHeading.ringKey(kMember.value)), findsNothing);
      expect(
        tester.widget<Text>(find.text('Owner')).style?.fontWeight,
        FontWeight.w500,
      );
      expect(
        tester.widget<Text>(find.text('Member')).style?.fontWeight,
        FontWeight.w400,
      );
      expect(
        find.descendant(
          of: find.byKey(StoriesHeading.rowKey),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
    });

    testWidgets('share calls openStoryCapture', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        var captures = 0;
        await pumpReady(tester, onCapture: (_) => captures++);
        await tester.pump();

        expect(find.bySemanticsLabel('Share a story'), findsOneWidget);
        await tester.tap(find.byKey(DateHeading.shareKey));
        expect(captures, 1);
      } finally {
        semantics.dispose();
      }
    });
  });

  group('week strip and agenda', () {
    const monday = DayKey(2026, 9, 28);
    const tuesday = DayKey(2026, 9, 29);
    const wednesday = DayKey(2026, 9, 30);
    const today = DayKey(2026, 9, 27);

    testWidgets('event and memory dots, with the dot row always reserved', (
      tester,
    ) async {
      for (var i = 0; i < 3; i++) {
        await ds.createEvent(
          baseId: 'b1',
          createdBy: kOwner.value,
          input: inputAt(kToday.add(Duration(days: 1, hours: i)), title: 'M$i'),
        );
      }
      await pumpHome(
        tester,
        bases: () async => [kBase],
        selected: kBase,
        user: member,
        memoryDays: {monday, wednesday},
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(WeekStrip.eventDotKey(monday)), findsOneWidget);
      expect(find.byKey(WeekStrip.memoryDotKey(monday)), findsOneWidget);
      expect(find.byKey(WeekStrip.memoryDotKey(wednesday)), findsOneWidget);
      expect(find.byKey(WeekStrip.eventDotKey(wednesday)), findsNothing);
      expect(find.byKey(WeekStrip.eventDotKey(tuesday)), findsNothing);
      expect(find.byKey(WeekStrip.memoryDotKey(tuesday)), findsNothing);
      expect(
        tester.getSize(find.byKey(WeekStrip.dayKey(monday))).height,
        tester.getSize(find.byKey(WeekStrip.dayKey(tuesday))).height,
      );
    });

    testWidgets('today is filled and another day selects with an outline', (
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

      BoxDecoration circle(DayKey day) {
        return tester
            .widget<DecoratedBox>(
              find.descendant(
                of: find.byKey(WeekStrip.circleKey(day)),
                matching: find.byType(DecoratedBox),
              ),
            )
            .decoration as BoxDecoration;
      }

      expect(circle(today).color, CalendarTokens.accent);
      final numeral = tester.widget<Text>(
        find.descendant(
          of: find.byKey(WeekStrip.circleKey(today)),
          matching: find.text('27'),
        ),
      );
      expect(numeral.style?.color, Colors.white);
      expect(numeral.style?.fontWeight, FontWeight.w600);
      final initial = tester.widget<Text>(
        find.descendant(
          of: find.byKey(WeekStrip.dayKey(today)),
          matching: find.text('S'),
        ),
      );
      expect(initial.style?.color, CalendarTokens.inkLight);

      await tester.tap(find.byKey(WeekStrip.dayKey(tuesday)));
      await tester.pump();

      expect(circle(today).color, CalendarTokens.accent);
      expect(circle(today).border, isNull);
      final outline = circle(tuesday).border! as Border;
      expect(circle(tuesday).color, isNull);
      expect(outline.top.color, CalendarTokens.accent);
      expect(outline.top.width, 1.5);
    });

    testWidgets('an empty day selects and Add event pre-fills it', (
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

      await tester.tap(find.byKey(WeekStrip.dayKey(tuesday)));
      await tester.pump();
      expect(find.text(DayAgenda.emptyCopy), findsOneWidget);
      expect(find.byKey(DayAgenda.addKey), findsOneWidget);

      await tester.tap(find.byKey(DayAgenda.addKey));
      await tester.pumpAndSettle();
      expect(find.text('Tuesday, September 29, 2026'), findsOneWidget);
    });

    testWidgets('changing span selects today again', (tester) async {
      await ds.createEvent(
        baseId: 'b1',
        createdBy: kOwner.value,
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

      await tester.tap(find.byKey(WeekStrip.dayKey(monday)));
      await tester.pump();
      expect(find.text('My lunch'), findsOneWidget);

      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();
      expect(find.text('My lunch'), findsNothing);
      expect(find.text(DayAgenda.emptyCopy), findsOneWidget);
    });
  });

  group('shared today', () {
    testWidgets('is absent when there are no tiles', (tester) async {
      await pumpHome(
        tester,
        bases: () async => [kBase],
        selected: kBase,
        user: member,
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('SHARED TODAY'), findsNothing);

      await pumpHome(
        tester,
        bases: () async => [kBase],
        selected: kBase,
        user: member,
        stories: AsyncValue.data(
          StoriesHeadingData(
            authors: [StoriesHeadingAuthor(userId: kOwner, opened: false)],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byKey(StoriesHeading.rowKey), findsOneWidget);
      expect(find.text('SHARED TODAY'), findsNothing);
    });

    testWidgets('lays tiles out in three columns with the kept-until line', (
      tester,
    ) async {
      await pumpHome(
        tester,
        bases: () async => [kBase],
        selected: kBase,
        user: member,
        stories: AsyncValue.data(
          StoriesHeadingData(
            tiles: const [
              MediaRef(
                id: MediaId('s1'),
                type: MediaType.image,
                storageKey: 'a.jpg',
              ),
              MediaRef(
                id: MediaId('s2'),
                type: MediaType.image,
                storageKey: 'b.jpg',
              ),
              MediaRef(
                id: MediaId('s3'),
                type: MediaType.image,
                storageKey: 'c.jpg',
              ),
            ],
            keptUntil: DateTime(2026, 9, 28, 9, 41),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      // The tiles start resolving on the frame the feed becomes ready.
      await tester.pump();

      expect(find.byKey(SharedTodaySection.sectionKey), findsOneWidget);
      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 3);
      expect(delegate.childAspectRatio, 3 / 4);
      expect(find.byType(MediaTile), findsNWidgets(3));
      expect(find.byIcon(Icons.broken_image_outlined), findsNWidgets(3));
      expect(
        find.text(
          'Kept until 9:41 AM tomorrow, then moved to this day on the calendar.',
        ),
        findsOneWidget,
      );
    });
  });
}

class _ThrowingMediaStorage implements MediaStorage {
  @override
  Future<void> delete(String key) async {}

  @override
  Future<String> putBytes({
    required String key,
    required List<int> bytes,
    required String mimeType,
  }) async {
    return key;
  }

  @override
  Future<String> resolveUri(String key) async {
    throw StateError('storage-denied');
  }
}

Color _cellFill(WidgetTester tester, DayKey day) {
  return _cellDecoration(tester, day).color!;
}

BoxDecoration _cellDecoration(WidgetTester tester, DayKey day) {
  final boxes = tester.widgetList<DecoratedBox>(
    find.descendant(
      of: find.byKey(CalendarGrid.cellKey(day)),
      matching: find.byType(DecoratedBox),
    ),
  );
  return boxes.first.decoration as BoxDecoration;
}
