import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/sync_status.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/message.dart';
import 'package:moonbase_skeleton/features/chat/presentation/widgets/message_bubble.dart';

Message _msg(SyncStatus status) => Message(
      id: const MessageId('m1'),
      baseId: 'b1'.bid,
      userId: 'u1'.uid,
      content: 'hello',
      createdAt: DateTime.utc(2026, 9, 27),
      syncStatus: status,
    );

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('synced bubble shows neither spinner nor failed flag',
      (tester) async {
    await tester.pumpWidget(_host(MessageBubble(
      message: _msg(SyncStatus.synced),
      currentUserId: 'u1',
      senderNickname: 'kiddo',
    )));

    expect(find.byKey(MessageBubble.pendingKey('m1')), findsNothing);
    expect(find.byKey(MessageBubble.failedKey('m1')), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('hello'), findsOneWidget);
    expect(find.text('kiddo'), findsOneWidget);
  });

  testWidgets('uploading bubble shows a spinner and "Sending…"',
      (tester) async {
    await tester.pumpWidget(_host(MessageBubble(
      message: _msg(SyncStatus.uploading),
      currentUserId: 'u1',
    )));

    expect(find.byKey(MessageBubble.pendingKey('m1')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Sending…'), findsOneWidget);
    expect(find.byKey(MessageBubble.failedKey('m1')), findsNothing);
  });

  testWidgets(
      'failed bubble shows the flag, tap calls onRetry, dismiss '
      'calls onDiscard', (tester) async {
    var retries = 0;
    var discards = 0;
    await tester.pumpWidget(_host(MessageBubble(
      message: _msg(SyncStatus.failed),
      currentUserId: 'u1',
      onRetry: () => retries++,
      onDiscard: () => discards++,
    )));

    expect(find.byKey(MessageBubble.failedKey('m1')), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('Not sent · Tap to resend'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.text('hello'));
    await tester.pump();
    expect(retries, 1);
    expect(discards, 0);

    await tester.tap(find.byKey(MessageBubble.discardKey('m1')));
    await tester.pump();
    expect(discards, 1);
    expect(retries, 1);
  });

  testWidgets('failed bubble without onDiscard hides the dismiss affordance',
      (tester) async {
    await tester.pumpWidget(_host(MessageBubble(
      message: _msg(SyncStatus.failed),
      currentUserId: 'u1',
      onRetry: () {},
    )));

    expect(find.byKey(MessageBubble.discardKey('m1')), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
  });
}
