import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/features/profile/domain/entities/profile.dart';
import 'package:moonbase_skeleton/features/profile/domain/usecases/get_profile.dart';
import '../../../../test_utils/mocks_profile.dart';
import 'package:moonbase_skeleton/core/ids.dart';

/// Test suite for the GetProfile use case.
/// 
/// This test suite focuses on testing the core functionality
/// of the GetProfile use case in isolation.
void main() {
  late GetProfile useCase;
  late MockProfileRepository mockRepository;

  setUp(() {
    mockRepository = MockProfileRepository();
    useCase = GetProfile(mockRepository);
  });

  group('GetProfile', () {
    const testUserId = 'user123';
    final testProfile = Profile(
      userId: testUserId.uid,
      nickname: 'testuser',
      updatedAt: DateTime(2025, 1, 1),
    );

    test('should return Right(Profile?) when repository returns profile', () async {
      // Arrange
      when(() => mockRepository.getProfile(testUserId.uid))
          .thenAnswer((_) async => Right(testProfile));

      // Act
      final result = await useCase(GetProfileParams(testUserId.uid));

      // Assert
      expect(result, isA<Right<Failure, Profile?>>());
      result.match(
        (failure) => fail('Should not return failure'),
        (profile) {
          expect(profile?.userId, equals(testUserId.uid));
          expect(profile?.nickname, equals('testuser'));
        },
      );
      verify(() => mockRepository.getProfile(testUserId.uid)).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('should return Right(null) when repository returns null', () async {
      // Arrange
      when(() => mockRepository.getProfile(testUserId.uid))
          .thenAnswer((_) async => const Right(null));

      // Act
      final result = await useCase(GetProfileParams(testUserId.uid));

      // Assert
      expect(result, isA<Right<Failure, Profile?>>());
      result.match(
        (failure) => fail('Should not return failure'),
        (profile) => expect(profile, isNull),
      );
      verify(() => mockRepository.getProfile(testUserId.uid)).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('should return Left(Failure) when repository returns failure', () async {
      // Arrange
      const failure = UnknownFailure('Profile not found');
      when(() => mockRepository.getProfile(testUserId.uid))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(GetProfileParams(testUserId.uid));

      // Assert
      expect(result, isA<Left<Failure, Profile?>>());
      result.match(
        (failure) => expect(failure, equals(failure)),
        (profile) => fail('Should not return success'),
      );
      verify(() => mockRepository.getProfile(testUserId.uid)).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('should return Left(Failure) when repository returns failure', () async {
      // Arrange
      when(() => mockRepository.getProfile(testUserId.uid))
          .thenAnswer((_) async => const Left(CacheFailure('Repository error')));

      // Act
      final result = await useCase(GetProfileParams(testUserId.uid));

      // Assert
      expect(result, isA<Left<Failure, Profile?>>());
      result.match(
        (failure) => expect(failure, isA<CacheFailure>()),
        (profile) => fail('Should not return success'),
      );
      verify(() => mockRepository.getProfile(testUserId.uid)).called(1);
      verifyNoMoreInteractions(mockRepository);
    });
  });
}
