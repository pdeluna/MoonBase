import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:moonbase_skeleton/features/auth/presentation/providers/auth_providers.dart' show currentUserProvider;

/// Provider for the current user ID string
final currentUserIdProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.id.value;
});
