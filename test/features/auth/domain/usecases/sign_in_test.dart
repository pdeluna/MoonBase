import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/auth/domain/entities/user.dart';
import 'package:moonbase_skeleton/features/auth/domain/usecases/sign_in.dart';
import '../../../../test_utils/mocks_auth.dart';

/// Test suite for the SignIn use case.
/// 
/// This test suite follows TDD principles and tests the SignIn use case
/// in isolation by mocking its dependencies. It covers:
/// - Successful sign-in scenarios
/// - Error handling scenarios
/// - Repository interaction patterns
/// - Parameter validation
/// 
/// **TDD Approach:**
/// 1. Write failing tests first
/// 2. Implement minimal code to pass tests
/// 3. Refactor while keeping tests green
/// 4. Add edge cases and error scenarios
void main() {
  late SignIn useCase;
  late MockAuthRepository mockRepository;

  setUp(() {
    mockRepository = MockAuthRepository();
    useCase = SignIn(mockRepository);
  });

  group('SignIn', () {
    const testNickname = 'testuser';
    const testUserId = 'user123';
    
    final testUser = User(
      id: testUserId.uid,
      nickname: testNickname,
    );

    group('call', () {
      test('should return Right(User) when sign-in is successful', () async {
        // Arrange
        when(() => mockRepository.signIn(nickname: testNickname))
            .thenAnswer((_) async => Right(testUser));

        // Act
        final result = await useCase(const SignInParams(testNickname));

        // Assert
        expect(result, isA<Right<Failure, User>>());
        result.match(
          (failure) => fail('Should not return failure'),
          (user) {
            expect(user.id, equals(testUserId.uid));
            expect(user.nickname, equals(testNickname));
          },
        );
        verify(() => mockRepository.signIn(nickname: testNickname)).called(1);
        verifyNoMoreInteractions(mockRepository);
      });

      test('should return Left(Failure) when repository returns failure', () async {
        // Arrange
        const failure = UnknownFailure('Sign-in failed');
        when(() => mockRepository.signIn(nickname: testNickname))
            .thenAnswer((_) async => const Left(failure));

        // Act
        final result = await useCase(const SignInParams(testNickname));

        // Assert
        expect(result, isA<Left<Failure, User>>());
        result.match(
          (failure) => expect(failure, equals(failure)),
          (user) => fail('Should not return success'),
        );
        verify(() => mockRepository.signIn(nickname: testNickname)).called(1);
        verifyNoMoreInteractions(mockRepository);
      });

      test('should return Left(Failure) when repository returns failure', () async {
        // Arrange
        when(() => mockRepository.signIn(nickname: testNickname))
            .thenAnswer((_) async => const Left(CacheFailure('Repository error')));

        // Act
        final result = await useCase(const SignInParams(testNickname));

        // Assert
        expect(result, isA<Left<Failure, User>>());
        result.match(
          (failure) => expect(failure, isA<CacheFailure>()),
          (user) => fail('Should not return success'),
        );
        verify(() => mockRepository.signIn(nickname: testNickname)).called(1);
        verifyNoMoreInteractions(mockRepository);
      });

      test('should pass nickname parameter correctly to repository', () async {
        // Arrange
        const customNickname = 'customuser';
        when(() => mockRepository.signIn(nickname: customNickname))
            .thenAnswer((_) async => Right(testUser));

        // Act
        await useCase(const SignInParams(customNickname));

        // Assert
        verify(() => mockRepository.signIn(nickname: customNickname)).called(1);
        verifyNoMoreInteractions(mockRepository);
      });

      // The four cases below exercise the SignIn use case's input
      // validation contract (isValidNickname in core/validators.dart):
      // 1–24 chars, [A-Za-z0-9 _.\-] only, trimmed.
      // For invalid input the use case must short-circuit with
      // ValidationFailure and never reach the repository.

      test('should return ValidationFailure for empty nickname', () async {
        // Act
        final result = await useCase(const SignInParams(''));

        // Assert
        expect(result, isA<Left<Failure, User>>());
        result.match(
          (failure) => expect(failure, isA<ValidationFailure>()),
          (_) => fail('Should not return success for empty nickname'),
        );
        verifyNever(() => mockRepository.signIn(nickname: any(named: 'nickname')));
      });

      test('should return ValidationFailure for whitespace-only nickname', () async {
        // Act
        final result = await useCase(const SignInParams('   '));

        // Assert
        expect(result, isA<Left<Failure, User>>());
        result.match(
          (failure) => expect(failure, isA<ValidationFailure>()),
          (_) => fail('Should not return success for whitespace-only nickname'),
        );
        verifyNever(() => mockRepository.signIn(nickname: any(named: 'nickname')));
      });

      test('should return ValidationFailure for nickname longer than 24 chars', () async {
        // Arrange: 100 'a's exceeds the 24-char cap
        final longNickname = 'a' * 100;

        // Act
        final result = await useCase(SignInParams(longNickname));

        // Assert
        expect(result, isA<Left<Failure, User>>());
        result.match(
          (failure) => expect(failure, isA<ValidationFailure>()),
          (_) => fail('Should not return success for over-long nickname'),
        );
        verifyNever(() => mockRepository.signIn(nickname: any(named: 'nickname')));
      });

      test('should return ValidationFailure for disallowed special characters', () async {
        // Arrange: '@', '!', '#', '$', '%' are outside [A-Za-z0-9 _.\-]
        const specialNickname = r'user@123!#$%';

        // Act
        final result = await useCase(const SignInParams(specialNickname));

        // Assert
        expect(result, isA<Left<Failure, User>>());
        result.match(
          (failure) => expect(failure, isA<ValidationFailure>()),
          (_) => fail('Should not return success for disallowed characters'),
        );
        verifyNever(() => mockRepository.signIn(nickname: any(named: 'nickname')));
      });
    });

    group('SignInParams', () {
      test('should create SignInParams with correct nickname', () {
        // Act
        const params = SignInParams(testNickname);

        // Assert
        expect(params.nickname, equals(testNickname));
      });

      test('should support const constructor', () {
        // Act & Assert
        expect(() => const SignInParams(testNickname), returnsNormally);
      });

    });

    group('SignIn constructor', () {
      test('should create SignIn with repository dependency', () {
        // Act
        final signIn = SignIn(mockRepository);

        // Assert
        expect(signIn, isA<SignIn>());
        expect(signIn.repo, equals(mockRepository));
      });

      test('should support const constructor', () {
        // Act & Assert
        expect(() => SignIn(mockRepository), returnsNormally);
      });
    });

    group('UseCase interface compliance', () {
      test('should implement UseCase interface correctly', () {
        // Act
        final signIn = SignIn(mockRepository);

        // Assert
        expect(signIn, isA<SignIn>());
        // Verify it has the call method
        expect(signIn.call, isA<Function>());
      });

      test('should return Future<Either<Failure, User>> from call method', () async {
        // Arrange
        when(() => mockRepository.signIn(nickname: any(named: 'nickname')))
            .thenAnswer((_) async => Right(testUser));

        // Act
        final result = await useCase(const SignInParams(testNickname));

        // Assert
        expect(result, isA<Either<Failure, User>>());
      });
    });

    group('Error handling', () {
      test('should handle NetworkFailure from repository', () async {
        // Arrange
        const failure = NetworkFailure('Network error');
        when(() => mockRepository.signIn(nickname: testNickname))
            .thenAnswer((_) async => const Left(failure));

        // Act
        final result = await useCase(const SignInParams(testNickname));

        // Assert
        expect(result, isA<Left<Failure, User>>());
        result.match(
          (failure) => expect(failure, isA<NetworkFailure>()),
          (user) => fail('Should not return success'),
        );
      });

      test('should handle CacheFailure from repository', () async {
        // Arrange
        const failure = CacheFailure('Cache error');
        when(() => mockRepository.signIn(nickname: testNickname))
            .thenAnswer((_) async => const Left(failure));

        // Act
        final result = await useCase(const SignInParams(testNickname));

        // Assert
        expect(result, isA<Left<Failure, User>>());
        result.match(
          (failure) => expect(failure, isA<CacheFailure>()),
          (user) => fail('Should not return success'),
        );
      });

      test('should handle UnknownFailure from repository', () async {
        // Arrange
        const failure = UnknownFailure('Unknown error');
        when(() => mockRepository.signIn(nickname: testNickname))
            .thenAnswer((_) async => const Left(failure));

        // Act
        final result = await useCase(const SignInParams(testNickname));

        // Assert
        expect(result, isA<Left<Failure, User>>());
        result.match(
          (failure) => expect(failure, isA<UnknownFailure>()),
          (user) => fail('Should not return success'),
        );
      });
    });

    group('Integration scenarios', () {
      test('should handle multiple consecutive calls', () async {
        // Arrange
        when(() => mockRepository.signIn(nickname: any(named: 'nickname')))
            .thenAnswer((_) async => Right(testUser));

        // Act
        final result1 = await useCase(const SignInParams('user1'));
        final result2 = await useCase(const SignInParams('user2'));

        // Assert
        expect(result1, isA<Right<Failure, User>>());
        expect(result2, isA<Right<Failure, User>>());
        verify(() => mockRepository.signIn(nickname: 'user1')).called(1);
        verify(() => mockRepository.signIn(nickname: 'user2')).called(1);
        verifyNoMoreInteractions(mockRepository);
      });

      test('should handle mixed success and failure scenarios', () async {
        // Arrange
        const failure = UnknownFailure('Test failure');
        when(() => mockRepository.signIn(nickname: 'success'))
            .thenAnswer((_) async => Right(testUser));
        when(() => mockRepository.signIn(nickname: 'failure'))
            .thenAnswer((_) async => const Left(failure));

        // Act
        final successResult = await useCase(const SignInParams('success'));
        final failureResult = await useCase(const SignInParams('failure'));

        // Assert
        expect(successResult, isA<Right<Failure, User>>());
        expect(failureResult, isA<Left<Failure, User>>());
        verify(() => mockRepository.signIn(nickname: 'success')).called(1);
        verify(() => mockRepository.signIn(nickname: 'failure')).called(1);
        verifyNoMoreInteractions(mockRepository);
      });
    });
  });
}