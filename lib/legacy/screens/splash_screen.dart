import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moonbase_skeleton/features/auth/presentation/providers/auth_providers.dart';
import 'package:moonbase_skeleton/legacy/widgets/moon_spinner.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _canNavigate = false;
  bool _didNavigate = false;

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
        _tryNavigate();
      }
    });
  }

  void _tryNavigate() {
    if (!_canNavigate || _didNavigate || !mounted) return;
    final session = ref.read(currentUserProvider);
    if (session.isLoading) return;

    final signedIn = session.maybeWhen(
      data: (u) => u != null,
      orElse: () => false,
    );

    debugPrint('SplashScreen: Navigating to ${signedIn ? '/home' : '/login'}');
    _didNavigate = true;
    context.go(signedIn ? '/home' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentUserProvider);
    final scheme = Theme.of(context).colorScheme;

    debugPrint(
      'SplashScreen: Building with session: $session, '
      '_canNavigate: $_canNavigate',
    );

    if (_canNavigate && !session.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tryNavigate();
      });
    }

    return Scaffold(
      backgroundColor: scheme.primaryContainer.withValues(alpha: 0.2),
      body: const Center(
        child: MoonSpinner(
          size: 72,
          orbit: 18,
          duration: Duration(seconds: 1),
          assetPath: 'assets/images/logo.png',
        ),
      ),
    );
  }
}
