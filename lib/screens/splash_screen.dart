import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moonbase_skeleton/widgets/moon_spinner.dart';
import 'package:moonbase_skeleton/services/session_controller.dart';

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
        final session = ref.read(sessionProvider);
        session.when(
          data: (profile) {
            final signedIn = profile != null;
            debugPrint('SplashScreen: Navigating to ${signedIn ? '/home' : '/login'}');
            context.go(signedIn ? '/home' : '/login');
          },
          loading: () {
            debugPrint('SplashScreen: Still loading, staying on splash');
          },
          error: (error, stack) {
            debugPrint('SplashScreen: Error, navigating to login');
            context.go('/login');
          },
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final scheme = Theme.of(context).colorScheme;
    
    debugPrint('SplashScreen: Building with session state: $session, _canNavigate: $_canNavigate');
    
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
