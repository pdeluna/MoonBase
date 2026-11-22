import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/presentation/failure_presenter.dart';
import 'package:moonbase_skeleton/features/auth/data/datasources/firebase_auth_remote_data_source.dart';

void main() {
  group('FirebaseAuthRemoteDataSource.nicknameFromEmail', () {
    test('uses local-part before @', () {
      expect(
        FirebaseAuthRemoteDataSource.nicknameFromEmail('owner@example.com'),
        'owner',
      );
    });

    test('falls back to full string without @', () {
      expect(
        FirebaseAuthRemoteDataSource.nicknameFromEmail('no-at-sign'),
        'no-at-sign',
      );
    });
  });

  group('FirebaseAuthRemoteDataSource.mapAuthException', () {
    const raw =
        'The supplied auth credential is incorrect, malformed or has expired.';

    test('invalid-credential maps to the plain copy and keeps the raw detail',
        () {
      final mapped = FirebaseAuthRemoteDataSource.mapAuthException(
        FirebaseAuthException(code: 'invalid-credential', message: raw),
      );
      expect(mapped, isA<InvalidCredentialsFailure>());
      expect(mapped.message, kInvalidCredentialsCopy);
      expect(userMessage(mapped), kInvalidCredentialsCopy);
      expect(mapped.debugDetail, raw);
      expect(debugSummary(mapped), contains(raw));
    });

    test('unknown auth code does not leak the SDK sentence as user copy', () {
      final mapped = FirebaseAuthRemoteDataSource.mapAuthException(
        FirebaseAuthException(
          code: 'internal-error',
          message: 'An internal error has occurred.',
        ),
      );
      expect(userMessage(mapped), kGenericErrorCopy);
      expect(mapped.debugDetail, 'An internal error has occurred.');
    });
  });
}
