import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/bases/domain/usecases/generate_invite_code.dart';
import '../../../../test_utils/mocks_bases.dart';

void main() {
  setUpAll(registerBasesFallbacks);

  group('GenerateInviteCode', () {
    late MockBaseRepository mockRepository;
    late GenerateInviteCode usecase;

    setUp(() {
      mockRepository = MockBaseRepository();
      usecase = GenerateInviteCode(mockRepository);
    });

    group('Success cases', () {
      test('should generate invite code successfully and return Right with code', () async {
        // Arrange
        const expectedCode = 'ABC123';
        final baseId = 'base_123'.bid;
        final requesterUserId = 'user_456'.uid;
        
        when(() => mockRepository.generateInviteCode(
          baseId: any(named: 'baseId'),
          requesterUserId: any(named: 'requesterUserId'),
        )).thenAnswer((_) async => const Right(expectedCode));

        // Act
        final result = await usecase(GenerateInviteCodeParams(
          baseId: baseId,
          requesterUserId: requesterUserId,
        ));

        // Assert
        expect(result, isA<Right<Failure, String>>());
        result.match(
          (failure) => fail('Expected Right but got Left: $failure'),
          (code) {
            expect(code, equals(expectedCode));
            expect(code.length, greaterThan(0));
          },
        );

        verify(() => mockRepository.generateInviteCode(
          baseId: baseId,
          requesterUserId: requesterUserId,
        )).called(1);
        verifyNoMoreInteractions(mockRepository);
      });

      test('should handle different invite code formats', () async {
        // Arrange
        const testCodes = ['XYZ789', 'DEF456', 'GHI123'];
        
        for (final code in testCodes) {
          when(() => mockRepository.generateInviteCode(
            baseId: any(named: 'baseId'),
            requesterUserId: any(named: 'requesterUserId'),
          )).thenAnswer((_) async => Right(code));

          // Act
          final result = await usecase(GenerateInviteCodeParams(
            baseId: 'base_123'.bid,
            requesterUserId: 'user_456'.uid,
          ));

          // Assert
          expect(result, isA<Right<Failure, String>>());
          result.match(
            (failure) => fail('Expected Right but got Left: $failure'),
            (generatedCode) => expect(generatedCode, equals(code)),
          );
        }
      });
    });

    group('Failure cases', () {
      test('should return Left with CacheFailure when repository throws cache error', () async {
        // Arrange
        final baseId = 'base_123'.bid;
        final requesterUserId = 'user_456'.uid;
        const errorMessage = 'Failed to generate invite code - cache error';
        
        when(() => mockRepository.generateInviteCode(
          baseId: any(named: 'baseId'),
          requesterUserId: any(named: 'requesterUserId'),
        )).thenAnswer((_) async => const Left(CacheFailure(errorMessage)));

        // Act
        final result = await usecase(GenerateInviteCodeParams(
          baseId: baseId,
          requesterUserId: requesterUserId,
        ));

        // Assert
        expect(result, isA<Left<Failure, String>>());
        result.match(
          (failure) {
            expect(failure, isA<CacheFailure>());
            expect(failure.message, equals(errorMessage));
          },
          (code) => fail('Expected Left but got Right: $code'),
        );

        verify(() => mockRepository.generateInviteCode(
          baseId: baseId,
          requesterUserId: requesterUserId,
        )).called(1);
      });

      test('should return Left with NetworkFailure when repository has network issues', () async {
        // Arrange
        final baseId = 'base_123'.bid;
        final requesterUserId = 'user_456'.uid;
        const errorMessage = 'Network connection failed';
        
        when(() => mockRepository.generateInviteCode(
          baseId: any(named: 'baseId'),
          requesterUserId: any(named: 'requesterUserId'),
        )).thenAnswer((_) async => const Left(NetworkFailure(errorMessage)));

        // Act
        final result = await usecase(GenerateInviteCodeParams(
          baseId: baseId,
          requesterUserId: requesterUserId,
        ));

        // Assert
        expect(result, isA<Left<Failure, String>>());
        result.match(
          (failure) {
            expect(failure, isA<NetworkFailure>());
            expect(failure.message, equals(errorMessage));
          },
          (code) => fail('Expected Left but got Right: $code'),
        );
      });

      test('should return Left with UnknownFailure for unexpected errors', () async {
        // Arrange
        final baseId = 'base_123'.bid;
        final requesterUserId = 'user_456'.uid;
        const errorMessage = 'Unexpected error occurred';
        
        when(() => mockRepository.generateInviteCode(
          baseId: any(named: 'baseId'),
          requesterUserId: any(named: 'requesterUserId'),
        )).thenAnswer((_) async => const Left(UnknownFailure(errorMessage)));

        // Act
        final result = await usecase(GenerateInviteCodeParams(
          baseId: baseId,
          requesterUserId: requesterUserId,
        ));

        // Assert
        expect(result, isA<Left<Failure, String>>());
        result.match(
          (failure) {
            expect(failure, isA<UnknownFailure>());
            expect(failure.message, equals(errorMessage));
          },
          (code) => fail('Expected Left but got Right: $code'),
        );
      });
    });

    group('Parameter validation', () {
      test('should pass correct parameters to repository', () async {
        // Arrange
        final baseId = 'test_base_id'.bid;
        final requesterUserId = 'test_user_id'.uid;
        
        when(() => mockRepository.generateInviteCode(
          baseId: any(named: 'baseId'),
          requesterUserId: any(named: 'requesterUserId'),
        )).thenAnswer((_) async => const Right('TEST123'));

        // Act
        await usecase(GenerateInviteCodeParams(
          baseId: baseId,
          requesterUserId: requesterUserId,
        ));

        // Assert
        verify(() => mockRepository.generateInviteCode(
          baseId: baseId,
          requesterUserId: requesterUserId,
        )).called(1);
      });

      test('should handle empty string parameters', () async {
        // Arrange
        final baseId = ''.bid;
        final requesterUserId = ''.uid;
        
        when(() => mockRepository.generateInviteCode(
          baseId: any(named: 'baseId'),
          requesterUserId: any(named: 'requesterUserId'),
        )).thenAnswer((_) async => const Left(CacheFailure('Invalid parameters')));

        // Act
        final result = await usecase(GenerateInviteCodeParams(
          baseId: baseId,
          requesterUserId: requesterUserId,
        ));

        // Assert
        expect(result, isA<Left<Failure, String>>());
        verify(() => mockRepository.generateInviteCode(
          baseId: baseId,
          requesterUserId: requesterUserId,
        )).called(1);
      });
    });

    group('Edge cases', () {
      test('should handle repository returning null or empty invite code', () async {
        // Arrange
        when(() => mockRepository.generateInviteCode(
          baseId: any(named: 'baseId'),
          requesterUserId: any(named: 'requesterUserId'),
        )).thenAnswer((_) async => const Right(''));

        // Act
        final result = await usecase(GenerateInviteCodeParams(
          baseId: 'base_123'.bid,
          requesterUserId: 'user_456'.uid,
        ));

        // Assert
        expect(result, isA<Right<Failure, String>>());
        result.match(
          (failure) => fail('Expected Right but got Left: $failure'),
          (code) => expect(code, equals('')),
        );
      });

      test('should handle very long base and user IDs', () async {
        // Arrange
        final longBaseId = ('a' * 1000).bid;
        final longUserId = ('b' * 1000).uid;
        
        when(() => mockRepository.generateInviteCode(
          baseId: any(named: 'baseId'),
          requesterUserId: any(named: 'requesterUserId'),
        )).thenAnswer((_) async => const Right('LONG123'));

        // Act
        final result = await usecase(GenerateInviteCodeParams(
          baseId: longBaseId,
          requesterUserId: longUserId,
        ));

        // Assert
        expect(result, isA<Right<Failure, String>>());
        verify(() => mockRepository.generateInviteCode(
          baseId: longBaseId,
          requesterUserId: longUserId,
        )).called(1);
      });
    });
  });
}
