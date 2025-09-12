import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/features/profile/domain/entities/profile.dart';
import 'package:moonbase_skeleton/features/profile/domain/usecases/update_profile.dart';
import '../../../../test_utils/mocks_profile.dart';

/// Test suite for the UpdateProfile use case.
/// 
/// This test suite focuses on testing the core functionality
/// of the UpdateProfile use case in isolation.
void main() {
  late UpdateProfile useCase;
  late MockProfileRepository mockRepository;

  setUp(() {
    mockRepository = MockProfileRepository();
    useCase = UpdateProfile(mockRepository);
  });

  group('UpdateProfile', () {
    const testUserId = 'user123';
    const testNickname = 'newNickname';
    const testAvatarUrl = 'https://example.com/avatar.jpg';
    final testProfile = Profile(
      userId: testUserId,
      nickname: testNickname,
      avatarUrl: testAvatarUrl,
      updatedAt: DateTime(2025, 1, 2),
    );

    test('should return Right(Profile) when repository updates successfully', () async {
      // Arrange
      when(() => mockRepository.updateProfile(
        userId: testUserId,
        nickname: testNickname,
        avatarUrl: testAvatarUrl,
      )).thenAnswer((_) async => Right(testProfile));

      // Act
      final result = await useCase(const UpdateProfileParams(
        userId: testUserId,
        nickname: testNickname,
        avatarUrl: testAvatarUrl,
      ));

      // Assert
      expect(result, isA<Right<Failure, Profile>>());
      result.match(
        (failure) => fail('Should not return failure'),
        (profile) {
          expect(profile.userId, equals(testUserId));
          expect(profile.nickname, equals(testNickname));
          expect(profile.avatarUrl, equals(testAvatarUrl));
        },
      );
      verify(() => mockRepository.updateProfile(
        userId: testUserId,
        nickname: testNickname,
        avatarUrl: testAvatarUrl,
      )).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('should handle null optional parameters', () async {
      // Arrange
      when(() => mockRepository.updateProfile(
        userId: testUserId,
        nickname: null,
        avatarUrl: null,
      )).thenAnswer((_) async => Right(testProfile));

      // Act
      final result = await useCase(const UpdateProfileParams(userId: testUserId));

      // Assert
      expect(result, isA<Right<Failure, Profile>>());
      verify(() => mockRepository.updateProfile(
        userId: testUserId,
        nickname: null,
        avatarUrl: null,
      )).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('should return Left(Failure) when repository returns failure', () async {
      // Arrange
      const failure = UnknownFailure('Update failed');
      when(() => mockRepository.updateProfile(
        userId: testUserId,
        nickname: testNickname,
        avatarUrl: testAvatarUrl,
      )).thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(const UpdateProfileParams(
        userId: testUserId,
        nickname: testNickname,
        avatarUrl: testAvatarUrl,
      ));

      // Assert
      expect(result, isA<Left<Failure, Profile>>());
      result.match(
        (failure) => expect(failure, equals(failure)),
        (profile) => fail('Should not return success'),
      );
      verify(() => mockRepository.updateProfile(
        userId: testUserId,
        nickname: testNickname,
        avatarUrl: testAvatarUrl,
      )).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('should return Left(Failure) when repository returns failure', () async {
      // Arrange
      when(() => mockRepository.updateProfile(
        userId: testUserId,
        nickname: testNickname,
        avatarUrl: testAvatarUrl,
      )).thenAnswer((_) async => const Left(CacheFailure('Repository error')));

      // Act
      final result = await useCase(const UpdateProfileParams(
        userId: testUserId,
        nickname: testNickname,
        avatarUrl: testAvatarUrl,
      ));

      // Assert
      expect(result, isA<Left<Failure, Profile>>());
      result.match(
        (failure) => expect(failure, isA<CacheFailure>()),
        (profile) => fail('Should not return success'),
      );
      verify(() => mockRepository.updateProfile(
        userId: testUserId,
        nickname: testNickname,
        avatarUrl: testAvatarUrl,
      )).called(1);
      verifyNoMoreInteractions(mockRepository);
    });
  });
}
