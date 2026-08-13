import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/features/chat/domain/entities/chat_freshness.dart';
import 'package:moonbase_skeleton/features/chat/presentation/widgets/cached_messages_banner.dart';

void main() {
  const copy = CachedMessagesBanner.copy;

  Widget wrap({
    required ChatFreshness? freshness,
    required bool hasMessages,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: CachedMessagesBanner(
            freshness: freshness,
            hasMessages: hasMessages,
          ),
        ),
      );

  testWidgets('cached non-empty feed shows copy after delay', (tester) async {
    await tester.pumpWidget(
      wrap(freshness: ChatFreshness.cached, hasMessages: true),
    );
    expect(find.text(copy), findsNothing);

    await tester.pump(CachedMessagesBanner.delay);
    expect(find.text(copy), findsOneWidget);
  });

  testWidgets('cached empty feed never shows the banner', (tester) async {
    await tester.pumpWidget(
      wrap(freshness: ChatFreshness.cached, hasMessages: false),
    );
    await tester.pump(CachedMessagesBanner.delay);
    expect(find.text(copy), findsNothing);
  });

  testWidgets('live feed never shows the banner', (tester) async {
    await tester.pumpWidget(
      wrap(freshness: ChatFreshness.live, hasMessages: true),
    );
    await tester.pump(CachedMessagesBanner.delay);
    expect(find.text(copy), findsNothing);
  });

  testWidgets('cached then live before delay never flashes', (tester) async {
    await tester.pumpWidget(
      wrap(freshness: ChatFreshness.cached, hasMessages: true),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(
      wrap(freshness: ChatFreshness.live, hasMessages: true),
    );
    await tester.pump(CachedMessagesBanner.delay);
    expect(find.text(copy), findsNothing);
  });
}
