import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonbase_skeleton/core/either.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/auth/domain/entities/user.dart';
import 'package:moonbase_skeleton/features/auth/domain/usecases/sign_up.dart';
import '../../../../test_utils/mocks_auth.dart';

void main() {
  late SignUp useCase;
  late MockAuthRepository mockRepository;

  setUp(() {
    mockRepository = MockAuthRepository();
    useCase = SignUp(mockRepository);
  });

  group('SignUp', () {
    const testEmail = 'owner@example.com';
    const testPassword = 'secret1';
    const testUserId = 'user123';

    final testUser = User(
      id: testUserId.uid,
      nickname: 'owner',
    );

    test('should return Right(User) when sign-up is successful', () async {
      when(() => mockRepository.signUp(
            email: testEmail,
            password: testPassword,
          )).thenAnswer((_) async => Right(testUser));

      final result = await useCase(const SignUpParams(
        email: testEmail,
        password: testPassword,
      ));

      expect(result, isA<Right<Failure, User>>());
      verify(() => mockRepository.signUp(
            email: testEmail,
            password: testPassword,
          )).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('should return ValidationFailure for invalid email', () async {
      final result = await useCase(const SignUpParams(
        email: 'bad',
        password: testPassword,
      ));

      expect(result, isA<Left<Failure, User>>());
      result.match(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('Should not return success'),
      );
      verifyNever(() => mockRepository.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ));
    });

    test('should return ValidationFailure for short password', () async {
      final result = await useCase(const SignUpParams(
        email: testEmail,
        password: '123',
      ));

      expect(result, isA<Left<Failure, User>>());
      result.match(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('Should not return success'),
      );
      verifyNever(() => mockRepository.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ));
    });
  });
}
