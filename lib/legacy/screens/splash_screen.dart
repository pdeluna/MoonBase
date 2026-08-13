import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moonbase_skeleton/core/di/providers.dart' show sharedPrefsProvider;
import 'package:moonbase_skeleton/features/auth/presentation/controllers/auth_controller.dart';
import 'package:moonbase_skeleton/features/auth/presentation/providers/auth_providers.dart';
import 'package:moonbase_skeleton/legacy/widgets/moon_spinner.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _canNavigate = false;

  @override
  void initState() {
    super.initState();
    debugPrint('SplashScreen: initState called');
    // Always show spinner for at least 1 second, regardless of session state
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _canNavigate = true;
        });
        debugPrint('SplashScreen: _canNavigate set to true');
        
        // Navigate after minimum display time
        final user = ref.read(currentUserProvider);
        final signedIn = user != null;
        // TEMP DIAG_HANG — remove after incident root-cause confirmed
        final authAsync = ref.read(authControllerProvider).current;
        final localUid =
            ref.read(sharedPrefsProvider).getString('currentUserId');
        if (kDebugMode) {
          final authLabel = authAsync.when(
            data: (u) => 'data(uid=${u?.id.value ?? 'null'})',
            loading: () => 'loading',
            error: (e, _) => 'error($e)',
          );
          debugPrint(
            'DIAG_HANG splash.navigate branch=${signedIn ? '/home' : '/login'} '
            'signedIn=$signedIn currentUserUid=${user?.id.value ?? 'null'} '
            'authAsync=$authLabel prefs.currentUserId=${localUid ?? 'null'}',
          );
        }
        debugPrint('SplashScreen: Navigating to ${signedIn ? '/home' : '/login'}');
        context.go(signedIn ? '/home' : '/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final scheme = Theme.of(context).colorScheme;
    
    debugPrint('SplashScreen: Building with user: $user, _canNavigate: $_canNavigate');
    
    return Scaffold(
      backgroundColor: scheme.primaryContainer.withValues(alpha: 0.2),
      body: Center(
        child: _canNavigate 
          ? const SizedBox.shrink() // Let navigation happen
          : const MoonSpinner( // Beautiful moon spinner
              size: 72,
              orbit: 18,
              duration: Duration(seconds: 1),
              assetPath: 'assets/images/logo.png',
            ),
      ),
    );
  }
}
