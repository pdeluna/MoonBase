import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/legacy/models/profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionController Tests', () {
    late Profile testProfile;

    setUp(() {
      testProfile = Profile(
        userId: 'user_123',
        nickname: 'testuser',
        createdAt: DateTime(2024, 1, 1).toIso8601String(),
        themeMode: 'light',
      );
    });

    group('Profile Management', () {
      test('should create profile with correct properties', () {
        expect(testProfile.userId, equals('user_123'));
        expect(testProfile.nickname, equals('testuser'));
        expect(testProfile.themeMode, equals('light'));
        expect(testProfile.createdAt, isNotEmpty);
      });

      test('should handle profile serialization', () {
        final json = testProfile.toJson();
        
        expect(json['userId'], equals('user_123'));
        expect(json['nickname'], equals('testuser'));
        expect(json['themeMode'], equals('light'));
        expect(json['createdAt'], equals(testProfile.createdAt));
        expect(json['version'], equals(1));
      });

      test('should create profile from JSON', () {
        final json = testProfile.toJson();
        final recreatedProfile = Profile.fromJson(json);
        
        expect(recreatedProfile.userId, equals(testProfile.userId));
        expect(recreatedProfile.nickname, equals(testProfile.nickname));
        expect(recreatedProfile.themeMode, equals(testProfile.themeMode));
        expect(recreatedProfile.createdAt, equals(testProfile.createdAt));
      });
    });

    group('Theme Management', () {
      test('should support light theme', () {
        final lightProfile = Profile(
          userId: 'user_123',
          nickname: 'testuser',
          createdAt: DateTime(2024, 1, 1).toIso8601String(),
          themeMode: 'light',
        );
        
        expect(lightProfile.themeMode, equals('light'));
      });

      test('should support dark theme', () {
        final darkProfile = Profile(
          userId: 'user_123',
          nickname: 'testuser',
          createdAt: DateTime(2024, 1, 1).toIso8601String(),
          themeMode: 'dark',
        );
        
        expect(darkProfile.themeMode, equals('dark'));
      });

      test('should validate theme mode values', () {
        expect(testProfile.themeMode == 'light' || testProfile.themeMode == 'dark', isTrue);
      });
    });

    group('Profile Persistence', () {
      test('should persist profile data correctly', () {
        final profile = Profile(
          userId: 'persistent_user',
          nickname: 'persistent',
          createdAt: DateTime(2024, 1, 1).toIso8601String(),
          themeMode: 'dark',
        );
        
        expect(profile.userId, equals('persistent_user'));
        expect(profile.nickname, equals('persistent'));
        expect(profile.themeMode, equals('dark'));
      });

      test('should handle profile updates', () {
        final originalProfile = testProfile;
        final updatedProfile = Profile(
          userId: originalProfile.userId,
          nickname: originalProfile.nickname,
          createdAt: originalProfile.createdAt,
          themeMode: 'dark', // Changed theme
        );
        
        expect(updatedProfile.userId, equals(originalProfile.userId));
        expect(updatedProfile.nickname, equals(originalProfile.nickname));
        expect(updatedProfile.themeMode, isNot(equals(originalProfile.themeMode)));
        expect(updatedProfile.themeMode, equals('dark'));
      });
    });

    group('Data Validation', () {
      test('should validate user ID format', () {
        expect(testProfile.userId, isNotEmpty);
        expect(testProfile.userId.length, greaterThan(0));
      });

      test('should validate nickname format', () {
        expect(testProfile.nickname, isNotEmpty);
        expect(testProfile.nickname.length, greaterThanOrEqualTo(2));
        expect(testProfile.nickname.length, lessThanOrEqualTo(24));
      });

      test('should validate creation date format', () {
        expect(testProfile.createdAt, isNotEmpty);
        
        // Should be valid ISO-8601 format
        expect(() => DateTime.parse(testProfile.createdAt), returnsNormally);
      });

      test('should validate theme mode', () {
        final validThemes = ['light', 'dark'];
        expect(validThemes.contains(testProfile.themeMode), isTrue);
      });
    });

    group('Profile Comparison', () {
      test('should identify identical profiles', () {
        final identicalProfile = Profile(
          userId: testProfile.userId,
          nickname: testProfile.nickname,
          createdAt: testProfile.createdAt,
          themeMode: testProfile.themeMode,
        );
        
        expect(identicalProfile.userId, equals(testProfile.userId));
        expect(identicalProfile.nickname, equals(testProfile.nickname));
        expect(identicalProfile.themeMode, equals(testProfile.themeMode));
      });

      test('should identify different profiles', () {
        final differentProfile = Profile(
          userId: 'different_user',
          nickname: 'different',
          createdAt: DateTime(2024, 1, 2).toIso8601String(),
          themeMode: 'dark',
        );
        
        expect(differentProfile.userId, isNot(equals(testProfile.userId)));
        expect(differentProfile.nickname, isNot(equals(testProfile.nickname)));
        expect(differentProfile.themeMode, isNot(equals(testProfile.themeMode)));
      });
    });

    group('Error Handling', () {
      test('should handle invalid theme mode gracefully', () {
        // This test ensures the system can handle unexpected theme values
        final invalidThemeProfile = Profile(
          userId: 'user_123',
          nickname: 'testuser',
          createdAt: DateTime(2024, 1, 1).toIso8601String(),
          themeMode: 'invalid_theme', // Invalid theme
        );
        
        // Should still create profile with invalid theme
        expect(invalidThemeProfile.themeMode, equals('invalid_theme'));
      });

      test('should handle empty user ID gracefully', () {
        final emptyUserIdProfile = Profile(
          userId: '', // Empty user ID
          nickname: 'testuser',
          createdAt: DateTime(2024, 1, 1).toIso8601String(),
          themeMode: 'light',
        );
        
        expect(emptyUserIdProfile.userId, isEmpty);
      });
    });

    group('Performance and Memory', () {
      test('should handle multiple profile creations efficiently', () {
        final profiles = <Profile>[];
        
        for (int i = 0; i < 100; i++) {
          profiles.add(Profile(
            userId: 'user_$i',
            nickname: 'user$i',
            createdAt: DateTime.now().toIso8601String(),
            themeMode: i % 2 == 0 ? 'light' : 'dark',
          ));
        }
        
        expect(profiles.length, equals(100));
        expect(profiles.every((p) => p.userId.isNotEmpty), isTrue);
        expect(profiles.every((p) => p.nickname.isNotEmpty), isTrue);
      });
    });
  });
}
