import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/validators.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_event.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/calendar_window.dart';
import 'package:moonbase_skeleton/features/calendar/domain/entities/event_input.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/event_editor_sheet.dart';

import '../../../../test_utils/fakes_calendar.dart';

void main() {
  /// Opens the sheet the way the app does (modal bottom sheet) so `pop()`
  /// on success closes the sheet rather than the root route.
  Future<void> openEditor(
    WidgetTester tester, {
    required Future<Failure?> Function(EventInput) onSubmit,
    CalendarEvent? existing,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => EventEditorSheet(
                    window: CalendarWindow.defaults,
                    today: kToday,
                    existing: existing,
                    onSubmit: onSubmit,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(EventEditorSheet), findsOneWidget);
  }

  testWidgets('blank title is rejected client-side; nothing submitted',
      (tester) async {
    var calls = 0;
    await openEditor(tester, onSubmit: (_) async {
      calls++;
      return null;
    });
    await tester.enterText(find.byKey(EventEditorSheet.titleKey), '   ');
    await tester.tap(find.byKey(EventEditorSheet.saveKey));
    await tester.pump();
    expect(find.text(EventEditorSheet.titleError), findsOneWidget);
    expect(calls, 0);
    expect(find.byType(EventEditorSheet), findsOneWidget);
  });

  testWidgets(
      'title field caps input at 80 chars (81 typed → 80 submitted) and closes on success',
      (tester) async {
    EventInput? submitted;
    await openEditor(tester, onSubmit: (i) async {
      submitted = i;
      return null;
    });
    await tester.enterText(
      find.byKey(EventEditorSheet.titleKey),
      'x' * (kEventTitleMaxLen + 1),
    );
    await tester.tap(find.byKey(EventEditorSheet.saveKey));
    await tester.pumpAndSettle();
    expect(submitted, isNotNull);
    expect(submitted!.title.length, kEventTitleMaxLen);
    expect(find.byType(EventEditorSheet), findsNothing,
        reason: 'closed on success');
  });

  testWidgets('end before start is rejected client-side', (tester) async {
    var calls = 0;
    final start = DateTime(2026, 9, 27, 13).toUtc();
    // Entity does not validate; the sheet must catch the inverted times.
    final inverted = CalendarEvent(
      id: 'e1'.eid,
      baseId: kBase.id,
      title: 'Dinner',
      startAt: start,
      endAt: DateTime(2026, 9, 27, 8).toUtc(),
      allDay: false,
      createdBy: kMember,
      createdAt: start,
      updatedAt: start,
    );
    await openEditor(tester, existing: inverted, onSubmit: (_) async {
      calls++;
      return null;
    });
    expect(find.text('Edit event'), findsOneWidget);
    await tester.tap(find.byKey(EventEditorSheet.saveKey));
    await tester.pump();
    expect(find.text(EventEditorSheet.endBeforeStartError), findsOneWidget);
    expect(calls, 0);

    // Clearing the end time removes the error path and submits.
    await tester.tap(find.byTooltip('Clear end time'));
    await tester.pump();
    await tester.tap(find.byKey(EventEditorSheet.saveKey));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets(
      'all-day submit builds a local-midnight UTC start with null end; failure keeps sheet open',
      (tester) async {
    var calls = 0;
    await openEditor(tester, onSubmit: (i) async {
      calls++;
      expect(i.allDay, isTrue);
      expect(i.startAt, DateTime(2026, 9, 27).toUtc());
      expect(i.endAt, isNull);
      expect(i.title, 'Picnic');
      return const NetworkFailure('Offline');
    });
    await tester.enterText(find.byKey(EventEditorSheet.titleKey), 'Picnic');
    await tester.tap(find.byKey(EventEditorSheet.allDayKey));
    await tester.pump();
    expect(find.byKey(EventEditorSheet.startKey), findsNothing);

    await tester.tap(find.byKey(EventEditorSheet.saveKey));
    await tester.pump();
    await tester.pump();
    expect(calls, 1);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.byType(EventEditorSheet), findsOneWidget,
        reason: 'stays open on failure');
  });
}
