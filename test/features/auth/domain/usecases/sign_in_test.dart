import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/auth/domain/entities/user.dart';
import 'package:moonbase_skeleton/features/auth/domain/usecases/sign_in.dart';
import '../../../../test_utils/mocks_auth.dart';

void main() {
  late SignIn useCase;
  late MockAuthRepository mockRepository;

  setUp(() {
    mockRepository = MockAuthRepository();
    useCase = SignIn(mockRepository);
  });

  group('SignIn', () {
    const testEmail = 'owner@example.com';
    const testPassword = 'secret1';
    const testUserId = 'user123';
    const testNickname = 'owner';

    final testUser = User(
      id: testUserId.uid,
      nickname: testNickname,
    );

    group('call', () {
      test('should return Right(User) when sign-in is successful', () async {
        when(() => mockRepository.signIn(
              email: testEmail,
              password: testPassword,
            )).thenAnswer((_) async => Right(testUser));

        final result = await useCase(const SignInParams(
          email: testEmail,
          password: testPassword,
        ));

        expect(result, isA<Right<Failure, User>>());
        result.match(
          (failure) => fail('Should not return failure'),
          (user) {
            expect(user.id, equals(testUserId.uid));
            expect(user.nickname, equals(testNickname));
          },
        );
        verify(() => mockRepository.signIn(
              email: testEmail,
              password: testPassword,
            )).called(1);
        verifyNoMoreInteractions(mockRepository);
      });

      test('should return Left(Failure) when repository returns failure',
          () async {
        const failure = UnknownFailure('Sign-in failed');
        when(() => mockRepository.signIn(
              email: testEmail,
              password: testPassword,
            )).thenAnswer((_) async => const Left(failure));

        final result = await useCase(const SignInParams(
          email: testEmail,
          password: testPassword,
        ));

        expect(result, isA<Left<Failure, User>>());
        result.match(
          (f) => expect(f, equals(failure)),
          (_) => fail('Should not return success'),
        );
        verify(() => mockRepository.signIn(
              email: testEmail,
              password: testPassword,
            )).called(1);
        verifyNoMoreInteractions(mockRepository);
      });

      test('should trim email before calling repository', () async {
        when(() => mockRepository.signIn(
              email: testEmail,
              password: testPassword,
            )).thenAnswer((_) async => Right(testUser));

        await useCase(const SignInParams(
          email: '  owner@example.com  ',
          password: testPassword,
        ));

        verify(() => mockRepository.signIn(
              email: testEmail,
              password: testPassword,
            )).called(1);
        verifyNoMoreInteractions(mockRepository);
      });

      test('should return ValidationFailure for empty email', () async {
        final result = await useCase(const SignInParams(
          email: '',
          password: testPassword,
        ));

        expect(result, isA<Left<Failure, User>>());
        result.match(
          (failure) => expect(failure, isA<ValidationFailure>()),
          (_) => fail('Should not return success for empty email'),
        );
        verifyNever(() => mockRepository.signIn(
              email: any(named: 'email'),
              password: any(named: 'password'),
            ));
      });

      test('should return ValidationFailure for email without @', () async {
        final result = await useCase(const SignInParams(
          email: 'not-an-email',
          password: testPassword,
        ));

        expect(result, isA<Left<Failure, User>>());
        result.match(
          (failure) => expect(failure, isA<ValidationFailure>()),
          (_) => fail('Should not return success for invalid email'),
        );
        verifyNever(() => mockRepository.signIn(
              email: any(named: 'email'),
              password: any(named: 'password'),
            ));
      });

      test('should return ValidationFailure for short password', () async {
        final result = await useCase(const SignInParams(
          email: testEmail,
          password: '12345',
        ));

        expect(result, isA<Left<Failure, User>>());
        result.match(
          (failure) => expect(failure, isA<ValidationFailure>()),
          (_) => fail('Should not return success for short password'),
        );
        verifyNever(() => mockRepository.signIn(
              email: any(named: 'email'),
              password: any(named: 'password'),
            ));
      });
    });

    group('Error handling', () {
      test('should handle NetworkFailure from repository', () async {
        const failure = NetworkFailure('Network error');
        when(() => mockRepository.signIn(
              email: testEmail,
              password: testPassword,
            )).thenAnswer((_) async => const Left(failure));

        final result = await useCase(const SignInParams(
          email: testEmail,
          password: testPassword,
        ));

        expect(result, isA<Left<Failure, User>>());
        result.match(
          (f) => expect(f, isA<NetworkFailure>()),
          (_) => fail('Should not return success'),
        );
      });
    });
  });
}
