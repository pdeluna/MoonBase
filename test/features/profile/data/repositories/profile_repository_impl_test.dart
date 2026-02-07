import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/profile/data/repositories/profile_repository_impl.dart';

void main() {
  late ProfileRepositoryImpl repository;
  late SharedPreferences prefs;

  setUp(() async {
    // Clear SharedPreferences before each test
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = ProfileRepositoryImpl(prefs);
  });

  group('ProfileRepositoryImpl - Deletion with Duplicate Handles', () {
    test('should delete correct user when multiple users have same handle', () async {
      // Arrange: Create two users with the same handle "alice"
      
      // Sign in first user with "alice"
      final result1 = await repository.signInByHandleOrCreate('alice');
      expect(result1.isRight, isTrue);
      final profile1 = result1.getOrElse(() => throw Exception('Expected success'));
      expect(profile1.nickname, equals('alice'));
      
      // Create second user with a different handle first
      final result2 = await repository.signInByHandleOrCreate('alice2');
      expect(result2.isRight, isTrue);
      final profile2 = result2.getOrElse(() => throw Exception('Expected success'));
      
      // Update the second user to have the same handle as the first
      final updateResult = await repository.updateProfile(
        userId: profile2.userId,
        nickname: 'alice', // Same handle as first user
      );
      expect(updateResult.isRight, isTrue);
      
      // Verify both users exist
      final getResult1 = await repository.getProfile(profile1.userId);
      final getResult2 = await repository.getProfile(profile2.userId);
      expect(getResult1.isRight, isTrue);
      expect(getResult2.isRight, isTrue);
      
      // Act: Delete the first user
      final deleteResult = await repository.deleteProfile(profile1.userId);
      
      // Assert: First user should be deleted, second user should remain
      expect(deleteResult.isRight, isTrue);
      
      final getResult1After = await repository.getProfile(profile1.userId);
      final getResult2After = await repository.getProfile(profile2.userId);
      
      expect(getResult1After.isRight, isTrue);
      getResult1After.match(
        (failure) => fail('Should not return failure'),
        (profile) => expect(profile, isNull), // First user deleted
      );
      
      expect(getResult2After.isRight, isTrue);
      getResult2After.match(
        (failure) => fail('Should not return failure'),
        (profile) {
          expect(profile, isNotNull);
          expect(profile!.userId.value, equals(profile2.userId.value));
          expect(profile.nickname, equals('alice'));
        },
      );
    });

    test('should clean up handle mapping when most recent user is deleted', () async {
      // Arrange: Create user and sign them in
      final result = await repository.signInByHandleOrCreate('alice');
      expect(result.isRight, isTrue);
      final profile = result.getOrElse(() => throw Exception('Expected success'));
      
      // Verify handle mapping exists
      final handlesBefore = prefs.getString('handlesIndex');
      expect(handlesBefore, isNotNull);
      expect(handlesBefore!.contains('alice'), isTrue);
      
      // Act: Delete the user
      final deleteResult = await repository.deleteProfile(profile.userId);
      
      // Assert: Handle mapping should be cleaned up
      expect(deleteResult.isRight, isTrue);
      
      final handlesAfter = prefs.getString('handlesIndex');
      // Should be empty JSON object '{}' or null
      expect(handlesAfter == null || handlesAfter == '{}', isTrue);
    });

    test('should clear current user when current user is deleted', () async {
      // Arrange: Sign in a user
      final result = await repository.signInByHandleOrCreate('alice');
      expect(result.isRight, isTrue);
      final profile = result.getOrElse(() => throw Exception('Expected success'));
      
      // Verify current user is set
      final currentUserBefore = prefs.getString('currentUserId');
      expect(currentUserBefore, equals(profile.userId.value));
      
      // Act: Delete the current user
      final deleteResult = await repository.deleteProfile(profile.userId);
      
      // Assert: Current user should be cleared
      expect(deleteResult.isRight, isTrue);
      
      final currentUserAfter = prefs.getString('currentUserId');
      expect(currentUserAfter, isNull);
      
      final readCurrentResult = await repository.readCurrent();
      expect(readCurrentResult.isRight, isTrue);
      readCurrentResult.match(
        (failure) => fail('Should not return failure'),
        (currentProfile) => expect(currentProfile, isNull),
      );
    });

    test('should handle deletion of non-existent user gracefully', () async {
      // Arrange: Non-existent user ID
      const nonExistentUserId = UserId('non-existent-uuid');
      
      // Act: Try to delete non-existent user
      final deleteResult = await repository.deleteProfile(nonExistentUserId);
      
      // Assert: Should succeed (no-op)
      expect(deleteResult.isRight, isTrue);
    });

    test('should not affect other users when deleting one user', () async {
      // Arrange: Create two users with different handles
      final result1 = await repository.signInByHandleOrCreate('alice');
      final result2 = await repository.signInByHandleOrCreate('bob');
      
      expect(result1.isRight, isTrue);
      expect(result2.isRight, isTrue);
      
      final profile1 = result1.getOrElse(() => throw Exception('Expected success'));
      final profile2 = result2.getOrElse(() => throw Exception('Expected success'));
      
      // Act: Delete first user
      final deleteResult = await repository.deleteProfile(profile1.userId);
      
      // Assert: Second user should be unaffected
      expect(deleteResult.isRight, isTrue);
      
      final getResult2 = await repository.getProfile(profile2.userId);
      expect(getResult2.isRight, isTrue);
      getResult2.match(
        (failure) => fail('Should not return failure'),
        (profile) {
          expect(profile, isNotNull);
          expect(profile!.userId.value, equals(profile2.userId.value));
          expect(profile.nickname, equals('bob'));
        },
      );
    });
  });

  group('ProfileRepositoryImpl - Handle Normalization', () {
    test('should normalize handles consistently', () async {
      // Arrange & Act: Sign in with different case variations
      final result1 = await repository.signInByHandleOrCreate('Alice');
      final result2 = await repository.signInByHandleOrCreate('alice');
      final result3 = await repository.signInByHandleOrCreate(' ALICE ');
      
      // Assert: All should return the same user (most recent)
      expect(result1.isRight, isTrue);
      expect(result2.isRight, isTrue);
      expect(result3.isRight, isTrue);
      
      final profile1 = result1.getOrElse(() => throw Exception('Expected success'));
      final profile2 = result2.getOrElse(() => throw Exception('Expected success'));
      final profile3 = result3.getOrElse(() => throw Exception('Expected success'));
      
      // All should be the same user (most recent)
      expect(profile1.userId.value, equals(profile3.userId.value));
      expect(profile2.userId.value, equals(profile3.userId.value));
    });
  });
}
