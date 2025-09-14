import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moonbase_skeleton/router.dart';
import 'package:moonbase_skeleton/services/session_controller.dart';

import 'package:moonbase_skeleton/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:moonbase_skeleton/features/profile/presentation/providers/profile_providers.dart' as profile_providers;

import 'package:moonbase_skeleton/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:moonbase_skeleton/features/auth/presentation/providers/auth_providers.dart';
import 'package:moonbase_skeleton/features/auth/data/datasources/auth_local_data_source_impl.dart';

import 'package:moonbase_skeleton/features/chat/data/datasources/chat_local_data_source_impl.dart';
import 'package:moonbase_skeleton/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:moonbase_skeleton/features/chat/presentation/providers/chat_providers.dart';

import 'package:moonbase_skeleton/features/bases/data/datasources/base_local_data_source_impl.dart';
import 'package:moonbase_skeleton/features/bases/data/repositories/base_repository_impl.dart';
import 'package:moonbase_skeleton/features/bases/presentation/providers/base_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  final overrides = <Override>[
    // Profile repo (backed by SharedPreferences)
    profile_providers.profileRepositoryProvider.overrideWithValue(ProfileRepositoryImpl(prefs)),

    // Auth repo (local only, via the tiny impl above)
    authRepositoryProvider.overrideWithValue(
      AuthRepositoryImpl(local: AuthLocalDataSourceImpl(prefs)),
    ),

    // Chat repo (dev-only in-memory)
    chatRepositoryProvider.overrideWithValue(
      ChatRepositoryImpl(local: InMemoryChatLocalDataSource()),
    ),

    // Bases repo (local dev store)
    baseRepositoryProvider.overrideWithValue(
      BaseRepositoryImpl(local: InMemoryBaseLocalDataSource()),
    ),
  ];

  runApp(ProviderScope(overrides: overrides, child: const MoonBaseApp()));
}


class MoonBaseApp extends ConsumerStatefulWidget {
  const MoonBaseApp({super.key});

  /// Helper to access the state anywhere to change theme.
  static MoonBaseAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<MoonBaseAppState>();
  @override
  ConsumerState<MoonBaseApp> createState() => MoonBaseAppState();
}

class MoonBaseAppState extends ConsumerState<MoonBaseApp> {
  ThemeMode _mode = ThemeMode.light;

  // Public getter to access the current theme mode
  ThemeMode get currentThemeMode => _mode;

  void setThemeMode(ThemeMode mode) => setState(() => _mode = mode);
  void toggleDark(bool isDark) =>
      setState(() => _mode = isDark ? ThemeMode.dark : ThemeMode.light);

  // ---- Palettes ----
  static const _seed = Color(0xFF06B6D4); // Indigo 500 accent
  ThemeData get _lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(centerTitle: true),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w700,
            fontSize: 32,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w600,
            fontSize: 28,
          ),
          headlineSmall: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w600,
            fontSize: 24,
          ),
          titleLarge: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w500,
            fontSize: 22,
          ),
          titleMedium: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
          titleSmall: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          bodyLarge: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w400,
            fontSize: 16,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w400,
            fontSize: 14,
          ),
          bodySmall: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w400,
            fontSize: 12,
          ),
          labelLarge: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          labelMedium: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          labelSmall: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w500,
            fontSize: 10,
          ),
        ),
      );

  ThemeData get _darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFF1A1C2C), // background
        appBarTheme: const AppBarTheme(
          centerTitle: true,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w700,
            fontSize: 32,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w600,
            fontSize: 28,
          ),
          headlineSmall: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w600,
            fontSize: 24,
          ),
          titleLarge: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w500,
            fontSize: 22,
          ),
          titleMedium: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
          titleSmall: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          bodyLarge: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w400,
            fontSize: 16,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w400,
            fontSize: 14,
          ),
          bodySmall: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w400,
            fontSize: 12,
          ),
          labelLarge: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          labelMedium: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          labelSmall: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w500,
            fontSize: 10,
          ),
        ),
      );
  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    // TODO: Implement theme persistence with new auth system
    // final user = ref.watch(currentUserProvider);
    // final storedTheme = user?.themeMode; // "light" | "dark"
    


    // Keep in sync without setState (safe in build)
    // if (storedTheme != null) {
    //   final newMode = storedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
    //   if (_mode != newMode) {
    //     debugPrint('MainApp: Updating theme from ${_mode.name} to ${newMode.name}');
    //     _mode = newMode;
    //   }
    // } else {
    //   // Reset to light mode when logged out
    //   if (_mode != ThemeMode.light) {
    //     debugPrint('MainApp: Resetting theme to light mode (logged out)');
    //     _mode = ThemeMode.light;
    //   }
    // }

    return MaterialApp.router(
      routerConfig: router,
      title: 'MoonBase',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: _lightTheme,
      darkTheme: _darkTheme,
    );
  }
}
