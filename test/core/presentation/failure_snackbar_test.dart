import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/presentation/failure_snackbar.dart';

const _longMessage =
    'This is a deliberately long failure message that would never fit on a '
    'single line of a phone-width snackbar and must still be shown in full, '
    'wrapping onto as many lines as it needs without an ellipsis.';

Widget _host({
  required void Function(BuildContext context) onPressed,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => onPressed(context),
            child: const Text('boom'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the full multi-line user copy (no truncation)',
      (tester) async {
    await tester.pumpWidget(_host(
      onPressed: (context) => showFailureSnackBar(
        context,
        const ValidationFailure(_longMessage),
        showDebugDetails: false,
      ),
    ));
    await tester.tap(find.text('boom'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));

    final textFinder = find.descendant(
      of: find.byType(SnackBar),
      matching: find.text(_longMessage),
    );
    expect(textFinder, findsOneWidget);
    final text = tester.widget<Text>(textFinder);
    expect(text.maxLines, isNull);
    expect(text.overflow, isNot(TextOverflow.ellipsis));
    // Rendered on more than one line: the RenderParagraph is taller than a
    // single line of its own style.
    final size = tester.getSize(textFinder);
    final lineHeight = (text.style?.fontSize ?? 14) * 1.5;
    expect(size.height, greaterThan(lineHeight));
  });

  testWidgets('prefix is prepended and Exception: never leaks', (tester) async {
    await tester.pumpWidget(_host(
      onPressed: (context) => showFailureSnackBar(
        context,
        Exception('Base not found'),
        prefix: 'Failed to join base',
        showDebugDetails: false,
      ),
    ));
    await tester.tap(find.text('boom'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));

    expect(find.text('Failed to join base: Base not found'), findsOneWidget);
    expect(find.textContaining('Exception:'), findsNothing);
  });

  testWidgets('Retry action invokes onRetry', (tester) async {
    var retries = 0;
    await tester.pumpWidget(_host(
      onPressed: (context) => showFailureSnackBar(
        context,
        const NetworkFailure(),
        onRetry: () => retries++,
        showDebugDetails: false,
      ),
    ));
    await tester.tap(find.text('boom'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(retries, 1);
  });

  testWidgets('showDebugDetails: true → Details action opens raw dialog',
      (tester) async {
    await tester.pumpWidget(_host(
      onPressed: (context) => showFailureSnackBar(
        context,
        const NetworkFailure('retry-limit-exceeded'),
        showDebugDetails: true,
      ),
    ));
    await tester.tap(find.text('boom'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));

    expect(find.text('Details'), findsOneWidget);
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('type: NetworkFailure'), findsOneWidget);
    expect(
      find.textContaining('failure message: retry-limit-exceeded'),
      findsOneWidget,
    );
  });

  testWidgets('showDebugDetails: false → no Details action, no tooltip',
      (tester) async {
    await tester.pumpWidget(_host(
      onPressed: (context) => showFailureSnackBar(
        context,
        const NetworkFailure(),
        showDebugDetails: false,
      ),
    ));
    await tester.tap(find.text('boom'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));

    expect(find.text('Details'), findsNothing);
    expect(find.byType(Tooltip), findsNothing);
    expect(find.byType(SnackBarAction), findsNothing);
  });

  testWidgets('Retry wins over Details when both are possible', (tester) async {
    await tester.pumpWidget(_host(
      onPressed: (context) => showFailureSnackBar(
        context,
        const NetworkFailure(),
        onRetry: () {},
        showDebugDetails: true,
      ),
    ));
    await tester.tap(find.text('boom'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));

    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Details'), findsNothing);
    // Long-press on the body still reaches the debug dialog.
    await tester.longPress(find.textContaining("Can't reach MoonBase"));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
