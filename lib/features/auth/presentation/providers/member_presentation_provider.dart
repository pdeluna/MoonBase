import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';

import 'package:moonbase_skeleton/core/user_color_utils.dart';
import 'package:moonbase_skeleton/core/di/providers.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/profile/presentation/providers/profile_providers.dart';

class MemberPresentation {
  const MemberPresentation({
    required this.nickname,
    required this.nameColor,
  });
  
  final String nickname;
  final Color nameColor;
}

/// Provider for member presentation (nickname + color) by user ID
/// Uses the new 3-layer architecture with proper error handling
final memberPresentationProvider = Provider.family<MemberPresentation, String>((ref, userId) {
  // Generate consistent color for this user ID
  final nameColor = UserColorUtils.getColorForUserId(userId);
  
  // Try to get profile from the new profile repository
  final profileAsync = ref.watch(profileProvider(userId.uid));
  
  return profileAsync.when(
    data: (profile) {
      if (profile != null && profile.nickname.isNotEmpty) {
        return MemberPresentation(
          nickname: profile.nickname,
          nameColor: nameColor,
        );
      }
      // Profile exists but nickname is empty, fall back to legacy lookup
      return _getLegacyMemberPresentation(userId, nameColor, ref);
    },
    loading: () => _getLegacyMemberPresentation(userId, nameColor, ref),
    error: (_, __) => _getLegacyMemberPresentation(userId, nameColor, ref),
  );
});

/// Fallback method to check legacy profile systems
MemberPresentation _getLegacyMemberPresentation(String userId, Color nameColor, Ref ref) {
  // Get SharedPreferences to read profile data directly
  final prefs = ref.watch(sharedPrefsProvider);
  
  // Try new auth system first (profiles key)
  final profilesJson = prefs.getString('profiles');
  if (profilesJson != null) {
    try {
      final profiles = jsonDecode(profilesJson) as Map<String, dynamic>;
      final profileData = profiles[userId] as Map<String, dynamic>?;
      
      if (profileData != null) {
        final nickname = profileData['nickname'] as String?;
        if (nickname != null && nickname.isNotEmpty) {
          return MemberPresentation(
            nickname: nickname,
            nameColor: nameColor,
          );
        }
      }
    } catch (e) {
      // Error parsing new auth profiles - continue to fallback
    }
  }
  
  // Try old profile system (mb.users key)
  final oldUsersJson = prefs.getString('mb.users');
  if (oldUsersJson != null) {
    try {
      final users = jsonDecode(oldUsersJson) as Map<String, dynamic>;
      
      // Search through all users to find one with matching userId
      for (final entry in users.entries) {
        try {
          final userData = entry.value as Map<String, dynamic>;
          if (userData['userId'] == userId) {
            final nickname = userData['nickname'] as String?;
            if (nickname != null && nickname.isNotEmpty) {
              return MemberPresentation(
                nickname: nickname,
                nameColor: nameColor,
              );
            }
          }
        } catch (e) {
          // Skip corrupted entries
          continue;
        }
      }
    } catch (e) {
      // Error parsing old profile system - continue to fallback
    }
  }
  
  // Fallback to generated nickname
  final fallbackNickname = 'User ${userId.substring(0, 8)}...';
  return MemberPresentation(
    nickname: fallbackNickname,
    nameColor: nameColor,
  );
}
