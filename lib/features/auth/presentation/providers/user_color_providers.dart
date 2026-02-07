import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:moonbase_skeleton/core/user_color_utils.dart';
import 'package:moonbase_skeleton/features/auth/presentation/providers/auth_providers.dart' show currentUserProvider;

/// Provider for the current user's color
final currentUserColorProvider = Provider<Color>((ref) {
  final user = ref.watch(currentUserProvider);
  
  if (user == null) {
    // Return a default color when no user is logged in
    return Colors.grey;
  }
  
  return UserColorUtils.getColorForUserId(user.id.value);
});

/// Provider for the current user's avatar text color (contrasting)
final currentUserTextColorProvider = Provider<Color>((ref) {
  final userColor = ref.watch(currentUserColorProvider);
  return UserColorUtils.getContrastingColor(userColor);
});

/// Provider for the current user's lighter color (for hover states)
final currentUserLighterColorProvider = Provider<Color>((ref) {
  final userColor = ref.watch(currentUserColorProvider);
  return UserColorUtils.getLighterColor(userColor);
});

/// Provider for the current user's darker color (for pressed states)
final currentUserDarkerColorProvider = Provider<Color>((ref) {
  final userColor = ref.watch(currentUserColorProvider);
  return UserColorUtils.getDarkerColor(userColor);
});

/// Provider family for getting colors for any user ID
final userColorProvider = Provider.family<Color, String>((ref, userId) {
  return UserColorUtils.getColorForUserId(userId);
});

/// Provider family for getting contrasting text colors for any user ID
final userTextColorProvider = Provider.family<Color, String>((ref, userId) {
  final userColor = ref.watch(userColorProvider(userId));
  return UserColorUtils.getContrastingColor(userColor);
});
