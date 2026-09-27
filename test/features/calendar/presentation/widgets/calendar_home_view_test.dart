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
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/calendar_home_view.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/calendar_loading_skeleton.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/day_section.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/event_detail_sheet.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/no_base_view.dart';
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
        child: const MaterialApp(home: Scaffold(body: CalendarHomeView())),
      ),
    );
  }

  group('B-e no-base states', () {
    testWidgets('loading → skeleton, never the create prompt', (tester) async {
      final never = Completer<List<Base>>();
      await pumpHome(tester, bases: () => never.future, user: member);
      await tester.pump();
      expect(find.byType(CalendarLoadingSkeleton), findsOneWidget);
      expect(find.text(NoBaseView.noBasesTitle), findsNothing);
      expect(find.text(BasesUnreachableView.copy), findsNothing);
    });

    testWidgets('error → "Can\'t reach MoonBase" + Retry re-fetches bases',
        (tester) async {
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

    testWidgets('bases exist but none selected → pick-a-base copy',
        (tester) async {
      await pumpHome(tester, bases: () async => [kBase], user: member);
      await tester.pump();
      expect(find.text(NoBaseView.pickTitle), findsOneWidget);
    });
  });

  group('ready', () {
    testWidgets('empty window copy; owner sees gear, member does not',
        (tester) async {
      await pumpHome(tester,
          bases: () async => [kBase], selected: kBase, user: member);
      await tester.pump();
      await tester.pump();
      expect(find.text(CalendarHomeView.emptyWindowCopy), findsOneWidget);
      expect(find.byKey(WindowLabel.gearKey), findsNothing);
      expect(find.textContaining('7 days back'), findsOneWidget);
      // Member may add under the default policy → inline Add event button.
      expect(find.text('Add event'), findsOneWidget);

      await pumpHome(tester,
          bases: () async => [kBase], selected: kBase, user: owner);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(WindowLabel.gearKey), findsOneWidget);
    });

    testWidgets('member under ownerOnly: no Add event affordance',
        (tester) async {
      await ds.setSettings(
        baseId: 'b1',
        settings: CalendarSettings.defaults
            .copyWith(eventCreation: EventCreationPolicy.ownerOnly),
      );
      await pumpHome(tester,
          bases: () async => [kBase], selected: kBase, user: member);
      await tester.pump();
      await tester.pump();
      expect(find.text(CalendarHomeView.emptyWindowCopy), findsOneWidget);
      expect(find.text('Add event'), findsNothing);
    });

    testWidgets(
        'populated agenda: today pinned, cards with author chip, collapsed empty days, detail sheet permissions',
        (tester) async {
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
      await pumpHome(tester,
          bases: () async => [kBase], selected: kBase, user: member);
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Today ·'), findsOneWidget);
      expect(find.text('Owner dinner'), findsOneWidget);
      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('Bring dessert'), findsOneWidget);
      expect(find.text('My lunch'), findsOneWidget);
      expect(find.text(DaySectionTile.nothingPlanned), findsWidgets);
      expect(find.byType(CachedEventsBanner), findsOneWidget);
      expect(find.text(CachedEventsBanner.copy), findsNothing,
          reason: 'live feed');

      // Owner's event → read-only for a member.
      await tester.tap(find.text('Owner dinner'));
      await tester.pumpAndSettle();
      expect(find.byType(EventDetailSheet), findsOneWidget);
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

    testWidgets('cached feed shows the cached banner after the delay',
        (tester) async {
      ds.fromCache = true;
      await ds.createEvent(
          baseId: 'b1', createdBy: kOwner.value, input: inputAt(kToday));
      await pumpHome(tester,
          bases: () async => [kBase], selected: kBase, user: member);
      await tester.pump();
      await tester.pump();
      await tester.pump(CachedEventsBanner.delay);
      expect(find.text(CachedEventsBanner.copy), findsOneWidget);
    });
  });
}
