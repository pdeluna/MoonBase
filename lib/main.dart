import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moonbase_skeleton/app.dart';

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

import 'package:moonbase_skeleton/core/di/providers.dart' show sharedPrefsProvider;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  final overrides = <Override>[
    // SharedPreferences provider
    sharedPrefsProvider.overrideWithValue(prefs),

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

  runApp(ProviderScope(overrides: overrides, child: const App()));
}

