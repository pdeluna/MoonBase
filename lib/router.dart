import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:moonbase_skeleton/core/app_navigator.dart';
import 'package:moonbase_skeleton/features/auth/domain/entities/user.dart';
import 'package:moonbase_skeleton/features/auth/presentation/providers/auth_providers.dart';
import 'package:moonbase_skeleton/legacy/screens/splash_screen.dart';
import 'package:moonbase_skeleton/legacy/screens/login_screen.dart';
import 'package:moonbase_skeleton/legacy/screens/signup_screen.dart';
import 'package:moonbase_skeleton/legacy/screens/home_screen.dart';
import 'package:moonbase_skeleton/features/chat/presentation/screens/chat_screen.dart';
import 'package:moonbase_skeleton/legacy/screens/profile_screen.dart';
import 'package:moonbase_skeleton/legacy/screens/base_picker_screen.dart';
import 'package:moonbase_skeleton/features/bases/presentation/screens/invites_screen.dart';

/// Bridges the Riverpod session into GoRouter's `refreshListenable`.
///
/// The router is built **once** per [ProviderContainer]; auth transitions
/// only re-run `redirect` through this notifier. Rebuilding the [GoRouter]
/// itself on every session change (the previous design) handed
/// `MaterialApp.router` a new `routerConfig`, remounted the navigator tree
/// and discarded screen state — a wrong password wiped the login form and
/// its error (bug B-a).
class _SessionRefreshNotifier extends ChangeNotifier {
  void bump() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionRefreshNotifier();
  ref.onDispose(refresh.dispose);

  // listen, not watch: the provider body must never re-run on auth changes.
  ref.listen<AsyncValue<User?>>(currentUserProvider, (_, next) {
    debugPrint(
        'RouterProvider: Auth state changed, refreshing redirect: $next');
    refresh.bump();
  });

  debugPrint(
    'RouterProvider: Building router once with auth state: '
    '${ref.read(currentUserProvider)}',
  );

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignUpScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/chat', builder: (_, __) => const ChatScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(
          path: '/base-picker', builder: (_, __) => const BasePickerScreen()),
      GoRoute(path: '/invites', builder: (_, __) => const InvitesScreen()),
    ],
    redirect: (context, state) {
      final loc = state.uri.toString();
      final sessionNow = ref.read(currentUserProvider);
      final user = sessionNow.valueOrNull;
      debugPrint('Router: redirect called with location: $loc, user: $user');

      // Always allow splash screen to control its own timing
      if (loc == '/splash') {
        debugPrint('Router: Allowing splash screen to control timing');
        return null;
      }

      if (sessionNow.isLoading) {
        debugPrint('Router: Session loading, no redirect');
        return null;
      }

      final signedIn = sessionNow.maybeWhen(
        data: (u) => u != null,
        orElse: () => false,
      );

      // Not signed in → only allow login/signup
      if (!signedIn && loc != '/login' && loc != '/signup') {
        debugPrint('Router: Not signed in, redirecting to login');
        return '/login';
      }

      // Signed in → keep away from login/signup
      if (signedIn && (loc == '/login' || loc == '/signup')) {
        debugPrint('Router: Signed in, redirecting to home');
        return '/home';
      }

      debugPrint('Router: No redirect needed');
      return null;
    },
  );
  ref.onDispose(router.dispose);
  return router;
});
