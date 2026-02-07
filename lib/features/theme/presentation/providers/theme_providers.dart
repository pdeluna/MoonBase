import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:moonbase_skeleton/core/di/providers.dart' show sharedPrefsProvider;
import 'package:moonbase_skeleton/features/auth/presentation/providers/auth_providers.dart' show currentUserProvider;

/// Surface just the current user id for downstream providers (theme/chats).
final currentUserIdProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider);   // <-- auth source of truth
  return user?.id.value;
});


// Theme Controller using Notifier API for proper dependency tracking
final themeControllerProvider = NotifierProvider<ThemeController, ThemeMode>(() => ThemeController());

class ThemeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPrefsProvider);
    final userId = ref.watch(currentUserIdProvider); // <- important dependency
    
    // Load theme preference for this user
    final key = 'theme:${userId ?? "guest"}';
    final raw = prefs.getString(key);
    final theme = _decode(raw) ?? ThemeMode.light;
    
    return theme;
  }

  Future<void> set(ThemeMode mode) async {
    final prefs = ref.read(sharedPrefsProvider);
    final userId = ref.read(currentUserIdProvider);
    
    state = mode;
    final key = 'theme:${userId ?? "guest"}';
    await prefs.setString(key, _encode(mode));
  }

  String _encode(ThemeMode m) => m == ThemeMode.dark ? 'dark' : 'light';
  ThemeMode? _decode(String? s) => s == 'dark' ? ThemeMode.dark : s == 'light' ? ThemeMode.light : null;
}
