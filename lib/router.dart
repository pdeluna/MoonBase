import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/session_controller.dart';

import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/profile_screen.dart';


final routerProvider = Provider<GoRouter>((ref) {
  // Watch session state for router rebuilds

  final session = ref.watch(sessionProvider);

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

      // Hold on splash while bootstrapping
      if (session.isLoading) return loc == '/splash' ? null : '/splash';
      if (session.hasError) return '/splash';

      final signedIn = session.value != null;

      // Not signed in → only allow splash/login/signup
      if (!signedIn &&
          loc != '/login' &&
          loc != '/signup' &&
          loc != '/splash') {
        return '/login';
      }

      // Signed in → keep away from login/splash
      if (signedIn && (loc == '/login' || loc == '/splash')) {
        return '/home';
      }

      return null;
    },
  );
});
