import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/presentation/debug_error_details.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  const error = PermissionDeniedFailure('Storage rules denied the read.');

  testWidgets('enabled → tooltip with raw summary, long-press opens dialog',
      (tester) async {
    await tester.pumpWidget(_host(
      const DebugErrorDetails(
        error: error,
        enabled: true,
        child: Text('Could not load image'),
      ),
    ));

    expect(
      find.byTooltip('PermissionDeniedFailure: Storage rules denied the read.'),
      findsOneWidget,
    );

    await tester.longPress(find.text('Could not load image'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Error details (debug build)'), findsOneWidget);
    expect(
        find.textContaining('type: PermissionDeniedFailure'), findsOneWidget);
    expect(
      find.textContaining('raw: PermissionDeniedFailure(Storage rules denied'),
      findsOneWidget,
    );
    expect(find.text('Copy'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('enabled with stack trace → stack appears in dialog',
      (tester) async {
    final trace = StackTrace.fromString('#0 somewhere (x.dart:1:1)');
    await tester.pumpWidget(_host(
      DebugErrorDetails(
        error: error,
        stackTrace: trace,
        enabled: true,
        child: const Text('child'),
      ),
    ));
    await tester.longPress(find.text('child'));
    await tester.pumpAndSettle();
    expect(find.textContaining('#0 somewhere (x.dart:1:1)'), findsOneWidget);
  });

  testWidgets('disabled → child rendered untouched, no tooltip, no dialog',
      (tester) async {
    await tester.pumpWidget(_host(
      const DebugErrorDetails(
        error: error,
        enabled: false,
        child: Text('Could not load image'),
      ),
    ));

    expect(find.text('Could not load image'), findsOneWidget);
    expect(find.byType(Tooltip), findsNothing);
    expect(find.byType(GestureDetector), findsNothing);

    await tester.longPress(find.text('Could not load image'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('showDebugErrorDetails(enabled: false) is a no-op',
      (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(_host(Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));
    await showDebugErrorDetails(ctx, error, enabled: false);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
