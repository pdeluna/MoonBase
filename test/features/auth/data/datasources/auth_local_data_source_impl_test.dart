import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moonbase_skeleton/features/auth/data/datasources/auth_local_data_source_impl.dart';
import 'package:moonbase_skeleton/features/auth/data/models/user_model.dart';
import 'package:moonbase_skeleton/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:moonbase_skeleton/core/ids.dart';

void main() {
  late AuthLocalDataSourceImpl authDataSource;
  late ProfileRepositoryImpl profileRepository;
  late SharedPreferences prefs;

  setUp(() async {
    // Clear SharedPreferences before each test
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    authDataSource = AuthLocalDataSourceImpl(prefs);
    profileRepository = ProfileRepositoryImpl(prefs);
  });

  group('AuthLocalDataSourceImpl - Consistency with ProfileRepository', () {
    test('should read current user from profile storage', () async {
      // Arrange: Create a user through ProfileRepository
      final signInResult = await profileRepository.signInByHandleOrCreate('alice');
      expect(signInResult.isRight, isTrue);
      final profile = signInResult.getOrElse(() => throw Exception('Expected success'));

      // Act: Read current user through AuthLocalDataSource
      final currentUser = await authDataSource.readCurrentUser();

      // Assert: Should return the same user
      expect(currentUser, isNotNull);
      expect(currentUser!.id, equals(profile.userId.value));
      expect(currentUser.nickname, equals(profile.nickname));
    });

    test('should write current user and create profile entry', () async {
      // Arrange
      const userModel = UserModel(id: 'test-user-123', nickname: 'testuser');

      // Act: Write user through AuthLocalDataSource
      await authDataSource.writeCurrentUser(userModel);

      // Assert: Should be readable through ProfileRepository
      final getResult = await profileRepository.getProfile(userModel.id.uid);
      expect(getResult.isRight, isTrue);
      getResult.match(
        (failure) => fail('Should not return failure'),
        (profile) {
          expect(profile, isNotNull);
          expect(profile!.userId.value, equals(userModel.id));
          expect(profile.nickname, equals(userModel.nickname));
        },
      );

      // Should be readable through AuthLocalDataSource
      final currentUser = await authDataSource.readCurrentUser();
      expect(currentUser, isNotNull);
      expect(currentUser!.id, equals(userModel.id));
      expect(currentUser.nickname, equals(userModel.nickname));
    });

    test('should not overwrite existing profile when writing current user', () async {
      // Arrange: Create a profile with avatar through ProfileRepository
      final signInResult = await profileRepository.signInByHandleOrCreate('alice');
      expect(signInResult.isRight, isTrue);
      final originalProfile = signInResult.getOrElse(() => throw Exception('Expected success'));

      // Update profile with avatar
      final updateResult = await profileRepository.updateProfile(
        userId: originalProfile.userId,
        avatarUrl: 'https://example.com/avatar.jpg',
      );
      expect(updateResult.isRight, isTrue);

      // Act: Write current user through AuthLocalDataSource (sync nickname)
      final userModel = UserModel(
        id: originalProfile.userId.value,
        nickname: 'alice-updated',
      );
      await authDataSource.writeCurrentUser(userModel);

      // Assert: Profile should retain its avatar and pick up nickname sync
      final getResult = await profileRepository.getProfile(originalProfile.userId);
      expect(getResult.isRight, isTrue);
      getResult.match(
        (failure) => fail('Should not return failure'),
        (profile) {
          expect(profile, isNotNull);
          expect(profile!.avatarUrl, equals('https://example.com/avatar.jpg'));
          expect(profile.nickname, equals('alice-updated'));
        },
      );
    });

    test('should clear current user without deleting profiles', () async {
      // Arrange: Create a user
      final signInResult = await profileRepository.signInByHandleOrCreate('alice');
      expect(signInResult.isRight, isTrue);
      final profile = signInResult.getOrElse(() => throw Exception('Expected success'));

      // Verify user exists
      final currentUser = await authDataSource.readCurrentUser();
      expect(currentUser, isNotNull);

      // Act: Clear through AuthLocalDataSource
      await authDataSource.clear();

      // Assert: Current user should be null
      final currentUserAfter = await authDataSource.readCurrentUser();
      expect(currentUserAfter, isNull);

      // But profile should still exist
      final getResult = await profileRepository.getProfile(profile.userId);
      expect(getResult.isRight, isTrue);
      getResult.match(
        (failure) => fail('Should not return failure'),
        (profileAfter) {
          expect(profileAfter, isNotNull);
          expect(profileAfter!.userId.value, equals(profile.userId.value));
        },
      );
    });

    test('should maintain handle index consistency', () async {
      // Arrange
      const userModel = UserModel(id: 'test-user-456', nickname: 'bob');

      // Act: Write user through AuthLocalDataSource
      await authDataSource.writeCurrentUser(userModel);

      // Assert: Should be able to sign in by handle through ProfileRepository
      final signInResult = await profileRepository.signInByHandleOrCreate('bob');
      expect(signInResult.isRight, isTrue);
      final profile = signInResult.getOrElse(() => throw Exception('Expected success'));
      expect(profile.userId.value, equals(userModel.id));
    });

    test('should handle case-insensitive handle lookup', () async {
      // Arrange
      const userModel = UserModel(id: 'test-user-789', nickname: 'Charlie');

      // Act: Write user through AuthLocalDataSource
      await authDataSource.writeCurrentUser(userModel);

      // Assert: Should be able to sign in with different case
      final signInResult = await profileRepository.signInByHandleOrCreate('charlie');
      expect(signInResult.isRight, isTrue);
      final profile = signInResult.getOrElse(() => throw Exception('Expected success'));
      expect(profile.userId.value, equals(userModel.id));
    });

    test('should return null when no current user is set', () async {
      // Act & Assert
      final currentUser = await authDataSource.readCurrentUser();
      expect(currentUser, isNull);
    });

    test('should return null when current user profile is deleted', () async {
      // Arrange: Create and set current user
      const userModel = UserModel(id: 'test-user-deleted', nickname: 'deleteduser');
      await authDataSource.writeCurrentUser(userModel);

      // Verify user exists
      final currentUser = await authDataSource.readCurrentUser();
      expect(currentUser, isNotNull);

      // Delete profile through ProfileRepository
      final deleteResult = await profileRepository.deleteProfile(userModel.id.uid);
      expect(deleteResult.isRight, isTrue);

      // Act & Assert: Should return null since profile no longer exists
      final currentUserAfter = await authDataSource.readCurrentUser();
      expect(currentUserAfter, isNull);
    });

    test('should handle malformed profile data gracefully', () async {
      // Arrange: Manually create malformed profile data
      await prefs.setString('currentUserId', 'malformed-user');
      await prefs.setString('profiles', '{"malformed-user": {"userId": 123, "nickname": null}}');

      // Act: Should not crash and return a user with safe defaults
      final currentUser = await authDataSource.readCurrentUser();

      // Assert: Should return user with safe defaults
      expect(currentUser, isNotNull);
      expect(currentUser!.id, equals('malformed-user')); // Fallback to current user ID
      expect(currentUser.nickname, equals('')); // Empty string for null/missing nickname
    });

    test('should handle missing nickname field gracefully', () async {
      // Arrange: Create profile with missing nickname
      await prefs.setString('currentUserId', 'no-nickname-user');
      await prefs.setString('profiles', '{"no-nickname-user": {"userId": "no-nickname-user"}}');

      // Act: Should not crash
      final currentUser = await authDataSource.readCurrentUser();

      // Assert: Should return user with empty nickname
      expect(currentUser, isNotNull);
      expect(currentUser!.id, equals('no-nickname-user'));
      expect(currentUser.nickname, equals(''));
    });

    test('should handle wrong data types gracefully', () async {
      // Arrange: Create profile with wrong data types
      await prefs.setString('currentUserId', 'wrong-types-user');
      await prefs.setString('profiles', '{"wrong-types-user": {"userId": 456, "nickname": 789}}');

      // Act: Should not crash
      final currentUser = await authDataSource.readCurrentUser();

      // Assert: Should return user with safe defaults
      expect(currentUser, isNotNull);
      expect(currentUser!.id, equals('wrong-types-user')); // Fallback to current user ID
      expect(currentUser.nickname, equals('')); // Empty string for wrong type
    });
  });
}
