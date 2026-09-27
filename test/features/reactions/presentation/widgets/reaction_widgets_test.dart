import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/sync_status.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';
import 'package:moonbase_skeleton/features/chat/presentation/widgets/message_bubble.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_group.dart';
import 'package:moonbase_skeleton/features/reactions/domain/entities/reaction_kind.dart';
import 'package:moonbase_skeleton/features/reactions/presentation/widgets/reaction_chip_row.dart';
import 'package:moonbase_skeleton/features/reactions/presentation/widgets/reaction_picker_sheet.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

Message _msg({SyncStatus status = SyncStatus.synced}) => Message(
      id: const MessageId('m1'),
      baseId: 'b1'.bid,
      userId: 'u1'.uid,
      content: 'hello',
      createdAt: DateTime.utc(2026, 9, 27),
      syncStatus: status,
    );

void main() {
  group('ReactionChipRow', () {
    testWidgets(
        'renders one chip per kind with counts, highlights mine, and '
        'emits the tapped kind', (tester) async {
      const group = ReactionGroup(
        counts: {ReactionKind.heart: 2, ReactionKind.fire: 1},
        mine: ReactionKind.fire,
      );
      ReactionKind? tapped;
      await tester.pumpWidget(_host(
        ReactionChipRow(group: group, onTap: (k) => tapped = k),
      ));

      expect(find.byKey(ReactionChipRow.chipKey(ReactionKind.heart)),
          findsOneWidget);
      expect(find.byKey(ReactionChipRow.chipKey(ReactionKind.fire)),
          findsOneWidget);
      expect(
          find.byKey(ReactionChipRow.chipKey(ReactionKind.like)), findsNothing);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      final semantics = tester.getSemantics(
        find.byKey(ReactionChipRow.chipKey(ReactionKind.fire)),
      );
      expect(semantics.label, contains('you reacted'));
      final other = tester.getSemantics(
        find.byKey(ReactionChipRow.chipKey(ReactionKind.heart)),
      );
      expect(other.label, isNot(contains('you reacted')));

      await tester.tap(find.byKey(ReactionChipRow.chipKey(ReactionKind.heart)));
      expect(tapped, ReactionKind.heart);
    });

    testWidgets('empty group renders nothing', (tester) async {
      await tester.pumpWidget(
        _host(const ReactionChipRow(group: ReactionGroup.empty)),
      );
      expect(find.byType(InkWell), findsNothing);
    });
  });

  group('ReactionPickerSheet', () {
    testWidgets('shows the six kinds and returns the tapped one',
        (tester) async {
      ReactionKind? result;
      await tester.pumpWidget(_host(Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await ReactionPickerSheet.show(
              context,
              current: ReactionKind.heart,
            );
          },
          child: const Text('open'),
        ),
      )));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      for (final k in ReactionKind.values) {
        expect(find.byKey(ReactionPickerSheet.optionKey(k)), findsOneWidget,
            reason: k.name);
      }
      expect(find.text('Tap Heart again to remove'), findsOneWidget);

      await tester
          .tap(find.byKey(ReactionPickerSheet.optionKey(ReactionKind.wow)));
      await tester.pumpAndSettle();
      expect(result, ReactionKind.wow);
      expect(find.byType(ReactionPickerSheet), findsNothing);
    });
  });

  group('MessageBubble + reactions', () {
    testWidgets(
        'renders the chip row and opens the picker on long-press for '
        'a synced message', (tester) async {
      ReactionKind? reacted;
      await tester.pumpWidget(_host(MessageBubble(
        message: _msg(),
        currentUserId: 'u1',
        reactions: const ReactionGroup(
          counts: {ReactionKind.like: 3},
          mine: null,
        ),
        onReact: (k) => reacted = k,
      )));

      expect(find.byKey(ReactionChipRow.chipKey(ReactionKind.like)),
          findsOneWidget);

      await tester.longPress(find.text('hello'));
      await tester.pumpAndSettle();
      expect(find.byType(ReactionPickerSheet), findsOneWidget);

      await tester
          .tap(find.byKey(ReactionPickerSheet.optionKey(ReactionKind.fire)));
      await tester.pumpAndSettle();
      expect(reacted, ReactionKind.fire);
    });

    testWidgets('tapping an existing chip emits that kind', (tester) async {
      ReactionKind? reacted;
      await tester.pumpWidget(_host(MessageBubble(
        message: _msg(),
        currentUserId: 'u1',
        reactions: const ReactionGroup(
          counts: {ReactionKind.sad: 1},
          mine: ReactionKind.sad,
        ),
        onReact: (k) => reacted = k,
      )));
      await tester.tap(find.byKey(ReactionChipRow.chipKey(ReactionKind.sad)));
      expect(reacted, ReactionKind.sad);
    });

    testWidgets(
        'pending message: no chips, long-press does not open the '
        'picker', (tester) async {
      var reacted = 0;
      await tester.pumpWidget(_host(MessageBubble(
        message: _msg(status: SyncStatus.uploading),
        currentUserId: 'u1',
        reactions: const ReactionGroup(
          counts: {ReactionKind.like: 3},
          mine: null,
        ),
        onReact: (_) => reacted++,
      )));

      expect(find.byType(ReactionChipRow), findsNothing);
      await tester.longPress(find.text('hello'));
      // The uploading spinner animates forever — bounded pump, not settle.
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ReactionPickerSheet), findsNothing);
      expect(reacted, 0);
    });

    testWidgets('without onReact the row is read-only and long-press is inert',
        (tester) async {
      await tester.pumpWidget(_host(MessageBubble(
        message: _msg(),
        currentUserId: 'u1',
        reactions: const ReactionGroup(
          counts: {ReactionKind.like: 1},
          mine: null,
        ),
      )));
      expect(find.byType(ReactionChipRow), findsOneWidget);
      await tester.longPress(find.text('hello'));
      await tester.pumpAndSettle();
      expect(find.byType(ReactionPickerSheet), findsNothing);
    });
  });
}
