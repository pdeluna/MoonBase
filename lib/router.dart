import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:moonbase_skeleton/services/session_controller.dart';
import 'package:moonbase_skeleton/screens/splash_screen.dart';
import 'package:moonbase_skeleton/screens/login_screen.dart';
import 'package:moonbase_skeleton/screens/signup_screen.dart';
import 'package:moonbase_skeleton/screens/home_screen.dart';
import 'package:moonbase_skeleton/screens/chat_screen.dart';
import 'package:moonbase_skeleton/screens/profile_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Watch session state for router rebuilds
  final session = ref.watch(sessionProvider);
  debugPrint('RouterProvider: Rebuilding router with session state: $session');

  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignUpScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/chat', builder: (_, __) => const ChatScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
    ],
    redirect: (context, state) {
      final loc = state.uri.toString();
      debugPrint('Router: redirect called with location: $loc, session: $session');

      // Always allow splash screen to control its own timing
      if (loc == '/splash') {
        debugPrint('Router: Allowing splash screen to control timing');
        return null;
      }

      // While session is loading, redirect to splash
      if (session.isLoading) {
        debugPrint('Router: Session loading, redirecting to splash');
        return '/splash';
      }
      
      // If session has error, redirect to splash
      if (session.hasError) {
        debugPrint('Router: Session error, redirecting to splash');
        return '/splash';
      }

      final signedIn = session.value != null;

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
