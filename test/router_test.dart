import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/features/auth/domain/entities/user.dart';
import 'package:moonbase_skeleton/features/auth/presentation/controllers/auth_controller.dart';
import 'package:moonbase_skeleton/features/auth/presentation/providers/auth_providers.dart';
import 'package:moonbase_skeleton/legacy/screens/login_screen.dart';
import 'package:moonbase_skeleton/router.dart';

import 'test_utils/mocks_auth.dart';

const _wrongPasswordCopy = kInvalidCredentialsCopy;

MockAuthRepository _signedOutRepo({required Failure signInFailure}) {
  final repo = MockAuthRepository();
  when(repo.getCurrentUser)
      .thenAnswer((_) async => const Right<Failure, User?>(null));
  when(() => repo.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      )).thenAnswer((_) async => Left<Failure, User>(signInFailure));
  when(repo.signOut).thenAnswer((_) async => const Right<Failure, void>(null));
  return repo;
}

void main() {
  group('routerProvider', () {
    test('builds the GoRouter once across two auth transitions', () async {
      final repo = _signedOutRepo(
        signInFailure: const ValidationFailure(_wrongPasswordCopy),
      );
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final first = container.read(routerProvider);
      // Let AuthController.load() settle → data(null).
      await Future<void>.delayed(Duration.zero);
      expect(container.read(currentUserProvider),
          const AsyncValue<User?>.data(null));

      // Transition 1: signed-out → loading → error (wrong password).
      await container
          .read(authControllerProvider.notifier)
          .signIn('owner@example.com', 'wrong-pw');
      expect(container.read(currentUserProvider).hasError, isTrue);
      expect(identical(container.read(routerProvider), first), isTrue);

      // Transition 2: error → data(null) (sign out).
      await container.read(authControllerProvider.notifier).signOut();
      expect(container.read(currentUserProvider),
          const AsyncValue<User?>.data(null));
      expect(identical(container.read(routerProvider), first), isTrue);
    });

    testWidgets(
      'wrong password keeps the same LoginScreen State, email and shows the error',
      (tester) async {
        final repo = _signedOutRepo(
          signInFailure: const ValidationFailure(_wrongPasswordCopy),
        );
        late GoRouter router;
        await tester.pumpWidget(ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(repo)],
          child: Consumer(builder: (context, ref, _) {
            router = ref.watch(routerProvider);
            return MaterialApp.router(routerConfig: router);
          }),
        ));
        // Splash waits 1s, then navigates to /login for a signed-out session.
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        // Let the splash → login page transition finish so only one Scaffold
        // (and therefore one SnackBar host) remains mounted.
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.byType(LoginScreen), findsOneWidget);

        final stateBefore = tester.state(find.byType(LoginScreen));
        final routerBefore = router;

        await tester.enterText(
            find.byType(TextField).at(0), 'owner@example.com');
        await tester.enterText(find.byType(TextField).at(1), 'wrong-pw');
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
        await tester.pump(); // loading
        await tester.pump(); // error + setState
        await tester.pump(const Duration(milliseconds: 300)); // snackbar in

        // Same router, same route, same State — no remount.
        expect(identical(router, routerBefore), isTrue);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(
          identical(tester.state(find.byType(LoginScreen)), stateBefore),
          isTrue,
        );
        expect(
          router.routerDelegate.currentConfiguration.uri.toString(),
          '/login',
        );

        // Email retained, error visible inline and as a snackbar.
        final emailField =
            tester.widget<TextField>(find.byType(TextField).first);
        expect(emailField.controller?.text, 'owner@example.com');
        expect(emailField.decoration?.errorText, _wrongPasswordCopy);
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text(_wrongPasswordCopy), findsNWidgets(2));
        expect(find.textContaining('Exception'), findsNothing);
      },
    );
  });
}
