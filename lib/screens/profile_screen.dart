import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moonbase_skeleton/features/auth/presentation/controllers/auth_controller.dart' as auth_controller;
import 'package:moonbase_skeleton/features/auth/presentation/providers/auth_providers.dart' show currentUserProvider;
import 'package:moonbase_skeleton/features/auth/presentation/providers/user_color_providers.dart';
import 'package:moonbase_skeleton/features/theme/presentation/providers/theme_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);
    final userColor = ref.watch(currentUserColorProvider);
    final userTextColor = ref.watch(currentUserTextColorProvider);
    
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 24),
          CircleAvatar(
            radius: 40,
            backgroundColor: userColor,
            child: Text(
              user?.nickname.substring(0, 1).toUpperCase() ?? '?',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: userTextColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              user?.nickname ?? 'Guest',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              user?.id.value ?? 'No user ID',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Privacy'),
            subtitle: const Text('Your circle is invite-only.'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            onTap: () {},
          ),
          
          // Appearance
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: const Text('Dark Mode'),
            value: isDark,
            onChanged: (value) async {
              // Update theme using the theme controller
              ref.read(themeControllerProvider.notifier).set(
                value ? ThemeMode.dark : ThemeMode.light,
              );
            },
          ),
ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Log out'),
            onTap: () async {
              await ref.read(auth_controller.authControllerProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}
