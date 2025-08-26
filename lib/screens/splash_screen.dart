import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Simulate boot/auth check. Replace with Firebase later.
    Future.delayed(const Duration(seconds: 1), () {
      // For the skeleton, always go to Login. Toggle below to jump to Home.
      // TODO: Replace with actual authentication check
      // ignore: unused_local_variable
      bool isLoggedIn = false; 
      if (!mounted) return;
      context.go('/login');
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.primaryContainer.withValues(alpha: 0.2),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.waves_rounded, size: 72, color: scheme.primary),
            const SizedBox(height: 16),
            Text('MoonBase', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
