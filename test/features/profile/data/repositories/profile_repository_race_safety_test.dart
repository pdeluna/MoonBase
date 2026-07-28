import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moonbase_skeleton/features/profile/data/repositories/profile_repository_impl.dart';

void main() {
  late ProfileRepositoryImpl repository;
  late SharedPreferences prefs;

  setUp(() async {
    // Clear SharedPreferences before each test
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = ProfileRepositoryImpl.sharedPrefs(prefs);
  });

  group('ProfileRepositoryImpl - Race Safety', () {
    test('should handle concurrent signInByHandleOrCreate operations atomically', () async {
      // Arrange: Multiple concurrent operations trying to create the same user
      const handle = 'alice';
      
      // Act: Start multiple concurrent operations
      final futures = List.generate(5, (index) => 
        repository.signInByHandleOrCreate(handle)
      );
      
      final results = await Future.wait(futures);
      
      // Assert: All operations should succeed and return the same user
      expect(results.length, equals(5));
      
      // All results should be successful
      for (final result in results) {
        expect(result.isRight, isTrue);
      }
      
      // All should return the same user ID
      final firstUserId = results.first.getOrElse(() => throw Exception('Expected success')).userId;
      for (final result in results) {
        final profile = result.getOrElse(() => throw Exception('Expected success'));
        expect(profile.userId.value, equals(firstUserId.value));
        expect(profile.nickname, equals(handle));
      }
      
      // Only one user should exist in storage
      final profiles = prefs.getString('profiles');
      expect(profiles, isNotNull);
      // We can't access private methods, but we can verify through public API
      final getResult = await repository.getProfile(firstUserId);
      expect(getResult.isRight, isTrue);
      getResult.match(
        (failure) => fail('Should not return failure'),
        (profile) => expect(profile, isNotNull),
      );
    });

    test('should handle concurrent updateProfile operations atomically', () async {
      // Arrange: Create a user first
      final signInResult = await repository.signInByHandleOrCreate('alice');
      expect(signInResult.isRight, isTrue);
      final profile = signInResult.getOrElse(() => throw Exception('Expected success'));
      
      // Act: Multiple concurrent updates
      final futures = List.generate(3, (index) => 
        repository.updateProfile(
          userId: profile.userId,
          nickname: 'alice_updated_$index',
        )
      );
      
      final results = await Future.wait(futures);
      
      // Assert: All operations should succeed
      for (final result in results) {
        expect(result.isRight, isTrue);
      }
      
      // Verify the final state is consistent
      final getResult = await repository.getProfile(profile.userId);
      expect(getResult.isRight, isTrue);
      getResult.match(
        (failure) => fail('Should not return failure'),
        (finalProfile) {
          expect(finalProfile, isNotNull);
          // Should have one of the updated nicknames
          expect(finalProfile!.nickname, startsWith('alice_updated_'));
        },
      );
    });

    test('should handle concurrent deleteProfile operations atomically', () async {
      // Arrange: Create multiple users
      final result1 = await repository.signInByHandleOrCreate('alice');
      final result2 = await repository.signInByHandleOrCreate('bob');
      
      expect(result1.isRight, isTrue);
      expect(result2.isRight, isTrue);
      
      final profile1 = result1.getOrElse(() => throw Exception('Expected success'));
      final profile2 = result2.getOrElse(() => throw Exception('Expected success'));
      
      // Act: Try to delete the same user concurrently
      final futures = List.generate(3, (index) => 
        repository.deleteProfile(profile1.userId)
      );
      
      final results = await Future.wait(futures);
      
      // Assert: All operations should succeed
      for (final result in results) {
        expect(result.isRight, isTrue);
      }
      
      // Verify the user is deleted
      final getResult = await repository.getProfile(profile1.userId);
      expect(getResult.isRight, isTrue);
      getResult.match(
        (failure) => fail('Should not return failure'),
        (profile) => expect(profile, isNull),
      );
      
      // Verify other user is unaffected
      final getResult2 = await repository.getProfile(profile2.userId);
      expect(getResult2.isRight, isTrue);
      getResult2.match(
        (failure) => fail('Should not return failure'),
        (profile) {
          expect(profile, isNotNull);
          expect(profile!.userId.value, equals(profile2.userId.value));
        },
      );
    });

    test('should handle mixed concurrent operations atomically', () async {
      // Arrange: Create initial user
      final signInResult = await repository.signInByHandleOrCreate('alice');
      expect(signInResult.isRight, isTrue);
      final profile = signInResult.getOrElse(() => throw Exception('Expected success'));
      
      // Act: Mix of concurrent operations
      final futures = [
        repository.updateProfile(userId: profile.userId, nickname: 'alice_updated'),
        repository.signInByHandleOrCreate('bob'),
        repository.updateProfile(userId: profile.userId, avatarUrl: 'https://example.com/avatar.jpg'),
        repository.signInByHandleOrCreate('charlie'),
        repository.deleteProfile(profile.userId),
      ];
      
      final results = await Future.wait(futures);
      
      // Assert: All operations should succeed
      for (final result in results) {
        expect(result.isRight, isTrue);
      }
      
      // Verify final state is consistent
      // We can verify through public API that operations completed successfully
      // The key test is that all operations succeeded without throwing exceptions
      // and the final state is consistent (no data corruption)
      
      // Verify that we can still perform operations after the concurrent mix
      final finalSignInResult = await repository.signInByHandleOrCreate('david');
      expect(finalSignInResult.isRight, isTrue);
    });
  });
}
