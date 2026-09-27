import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/features/auth/domain/entities/user.dart';
import 'package:moonbase_skeleton/features/auth/presentation/providers/auth_providers.dart';
import 'package:moonbase_skeleton/legacy/screens/login_screen.dart';

import '../../test_utils/mocks_auth.dart';

const _wrongPasswordCopy = 'Invalid email or password.';
const _longCopy =
    'This account has been disabled by an administrator. Contact the base '
    'owner to have it re-enabled before trying to sign in again.';

Future<MockAuthRepository> _pumpLogin(
  WidgetTester tester, {
  required Failure failure,
}) async {
  final repo = MockAuthRepository();
  when(repo.getCurrentUser)
      .thenAnswer((_) async => const Right<Failure, User?>(null));
  when(() => repo.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      )).thenAnswer((_) async => Left<Failure, User>(failure));

  await tester.pumpWidget(ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
    child: const MaterialApp(home: LoginScreen()),
  ));
  await tester.pump();
  return repo;
}

Future<void> _submit(WidgetTester tester,
    {String password = 'wrong-pw'}) async {
  await tester.enterText(find.byType(TextField).at(0), 'owner@example.com');
  await tester.enterText(find.byType(TextField).at(1), password);
  await tester.pump();
  await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('wrong password shows the Failure.message inline, no prefix',
      (tester) async {
    await _pumpLogin(
      tester,
      failure: const ValidationFailure(_wrongPasswordCopy),
    );
    await _submit(tester);

    // Inline (errorText) and snackbar carry the same copy.
    expect(find.text(_wrongPasswordCopy), findsNWidgets(2));
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.textContaining('Failure('), findsNothing);
  });

  testWidgets('long failure copy is not clipped to one line', (tester) async {
    await _pumpLogin(tester, failure: const ValidationFailure(_longCopy));
    await _submit(tester);

    final emailField = tester.widget<TextField>(find.byType(TextField).first);
    expect(emailField.decoration?.errorText, _longCopy);
    expect(emailField.decoration?.errorMaxLines, greaterThanOrEqualTo(3));
    expect(find.text(_longCopy), findsWidgets);
  });

  testWidgets('email stays in the field after a failed sign-in',
      (tester) async {
    await _pumpLogin(
      tester,
      failure: const ValidationFailure(_wrongPasswordCopy),
    );
    await _submit(tester);

    final emailField = tester.widget<TextField>(find.byType(TextField).first);
    expect(emailField.controller?.text, 'owner@example.com');
    final passwordField =
        tester.widget<TextField>(find.byType(TextField).at(1));
    expect(passwordField.controller?.text, 'wrong-pw');
    expect(find.text(_wrongPasswordCopy), findsWidgets);
  });

  testWidgets('failure is also announced as a snackbar with the same copy',
      (tester) async {
    await _pumpLogin(
      tester,
      failure: const ValidationFailure(_wrongPasswordCopy),
    );
    await _submit(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text(_wrongPasswordCopy),
      ),
      findsOneWidget,
    );
  });

  testWidgets('NetworkFailure shows the plain login network copy',
      (tester) async {
    await _pumpLogin(tester, failure: const NetworkFailure('unavailable'));
    await _submit(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text(_LoginCopy.network),
      findsNWidgets(2), // inline + snackbar
    );
    expect(find.textContaining('unavailable'), findsNothing);
  });

  testWidgets('NetworkTimeoutFailure shows the plain login network copy',
      (tester) async {
    await _pumpLogin(tester, failure: const NetworkTimeoutFailure());
    await _submit(tester);

    final emailField = tester.widget<TextField>(find.byType(TextField).first);
    expect(emailField.decoration?.errorText, _LoginCopy.network);
  });

  test('signInCopy maps network failures, passes others to userMessage', () {
    expect(LoginScreen.signInCopy(const NetworkFailure()), _LoginCopy.network);
    expect(LoginScreen.signInCopy(const NetworkTimeoutFailure()),
        _LoginCopy.network);
    expect(LoginScreen.signInCopy(const ValidationFailure('Bad.')), 'Bad.');
    expect(LoginScreen.signInCopy(Exception('raw')), 'raw');
    expect(LoginScreen.signInCopy(null), 'Could not sign in. Try again.');
  });
}

abstract final class _LoginCopy {
  static const network = LoginScreen.kLoginNetworkCopy;
}
