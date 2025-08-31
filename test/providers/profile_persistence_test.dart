import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moonbase_skeleton/services/profile_repository.dart';
import 'package:moonbase_skeleton/models/profile.dart';

void main() {
  group('Profile Persistence with Case-Sensitive Nicknames', () {
    late SpProfileRepository repository;

    setUp(() async {
      // Clear SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
      repository = SpProfileRepository();
    });

    test('should create profiles with case-sensitive nicknames', () async {
      // Test case-sensitive nicknames
      final profile1 = await repository.signInByNickname('Alice');
      final profile2 = await repository.signInByNickname('alice');
      final profile3 = await repository.signInByNickname('ALICE');

      // All should be different profiles with different UUIDs
      expect(profile1.nickname, 'Alice');
      expect(profile2.nickname, 'alice');
      expect(profile3.nickname, 'ALICE');
      
      expect(profile1.userId, isNot(equals(profile2.userId)));
      expect(profile1.userId, isNot(equals(profile3.userId)));
      expect(profile2.userId, isNot(equals(profile3.userId)));
    });

    test('should persist and retrieve profiles correctly', () async {
      // Create a profile
      final originalProfile = await repository.signInByNickname('TestUser');
      expect(originalProfile.nickname, 'TestUser');
      expect(originalProfile.themeMode, 'light'); // Default theme

      // Read the profile back
      final retrievedProfile = await repository.read();
      expect(retrievedProfile, isNotNull);
      expect(retrievedProfile!.nickname, 'TestUser');
      expect(retrievedProfile.userId, originalProfile.userId);
      expect(retrievedProfile.themeMode, 'light');
    });

    test('should update theme and persist it', () async {
      // Create a profile
      final profile = await repository.signInByNickname('ThemeUser');
      
      // Update theme
      final updatedProfile = Profile(
        userId: profile.userId,
        nickname: profile.nickname,
        createdAt: profile.createdAt,
        themeMode: 'dark',
      );
      
      await repository.write(updatedProfile);
      
      // Read back and verify theme was persisted
      final retrievedProfile = await repository.read();
      expect(retrievedProfile, isNotNull);
      expect(retrievedProfile!.themeMode, 'dark');
    });

    test('should handle sign out correctly', () async {
      // Create and sign in
      await repository.signInByNickname('SignOutUser');
      expect(await repository.read(), isNotNull);
      
      // Sign out
      await repository.clear();
      expect(await repository.read(), isNull);
    });

    test('should validate UUID format', () async {
      final profile = await repository.signInByNickname('UUIDTest');
      
      // UUID should be a valid UUID v4 format
      final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$', caseSensitive: false);
      expect(uuidRegex.hasMatch(profile.userId), isTrue);
    });
  });
}
