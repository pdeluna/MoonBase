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

/// Rebuild trigger for [routerProvider]. Not a signed-in boolean — loading
/// and signed-out are distinct on [currentUserProvider].
final authStateProvider = Provider<AsyncValue<User?>>((ref) {
  return ref.watch(currentUserProvider);
});

final routerProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(authStateProvider);
  debugPrint('RouterProvider: Rebuilding router with auth state: $session');

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
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
});
