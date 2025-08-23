import 'package:flutter/material.dart';
import '../main.dart';

class ProfileScreen extends StatelessWidget {
  static const route = '/profile';
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 24),
          CircleAvatar(
            radius: 40,
            child: Text('PD', style: Theme.of(context).textTheme.titleLarge),
          ),
          const SizedBox(height: 12),
          Center(child: Text('Philip', style: Theme.of(context).textTheme.titleLarge)),
          const SizedBox(height: 4),
          Center(child: Text('philip@example.com', style: TextStyle(color: scheme.onSurfaceVariant))),
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
            value: MoonBaseApp.of(context)?.currentThemeMode == ThemeMode.dark,
            onChanged: (v) => MoonBaseApp.of(context)?.toggleDark(v),
          ),
          ListTile(
            leading: const Icon(Icons.brightness_auto),
            title: const Text('Use system theme'),
            subtitle: const Text('Match the device setting'),
            trailing: MoonBaseApp.of(context)?.currentThemeMode == ThemeMode.system
                ? Icon(Icons.check, color: scheme.primary) 
                : null,
            onTap: () => MoonBaseApp.of(context)?.setThemeMode(ThemeMode.system),
          ),
ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () {
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
          ),
        ],
      ),
    );
  }
}
