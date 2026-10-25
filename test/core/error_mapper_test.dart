import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/core/error_mapper.dart';
import 'package:moonbase_skeleton/core/failure.dart';

void main() {
  group('mapException FirebaseException', () {
    test('retry-limit-exceeded maps to NetworkFailure, not UnknownFailure', () {
      final mapped = mapException(
        FirebaseException(
          plugin: 'firebase_storage',
          code: 'retry-limit-exceeded',
          message: 'The operation retry limit has been exceeded.',
        ),
      );
      expect(mapped, isA<NetworkFailure>());
      expect(mapped, isNot(isA<UnknownFailure>()));
      expect(mapped, isNot(isA<NetworkTimeoutFailure>()));
    });

    test('unavailable maps to NetworkFailure', () {
      final mapped = mapException(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
          message: 'Failed to get document because the client is offline.',
        ),
      );
      expect(mapped, isA<NetworkFailure>());
      expect(mapped, isNot(isA<UnknownFailure>()));
    });
  });

  group('mapException Storage / rules access codes (B-b)', () {
    FirebaseException storage(String code) => FirebaseException(
          plugin: 'firebase_storage',
          code: code,
          message: 'sdk message for $code',
        );

    test('object-not-found → MediaNotFoundFailure with authored copy', () {
      final mapped = mapException(storage('object-not-found'));
      expect(mapped, isA<MediaNotFoundFailure>());
      expect(mapped.message, isNot(contains('sdk message')));
    });

    test('unauthorized → PermissionDeniedFailure', () {
      expect(
        mapException(storage('unauthorized')),
        isA<PermissionDeniedFailure>(),
      );
    });

    test('unauthenticated → PermissionDeniedFailure', () {
      expect(
        mapException(storage('unauthenticated')),
        isA<PermissionDeniedFailure>(),
      );
    });

    test('Firestore permission-denied → PermissionDeniedFailure', () {
      final mapped = mapException(FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions.',
      ));
      expect(mapped, isA<PermissionDeniedFailure>());
      expect(mapped.message, "You don't have permission to do that.");
    });

    test('invalid-credential → plain copy, Firebase sentence kept for debug',
        () {
      const raw =
          'The supplied auth credential is incorrect, malformed or has expired.';
      final mapped = mapException(FirebaseException(
        plugin: 'firebase_auth',
        code: 'invalid-credential',
        message: raw,
      ));
      expect(mapped, isA<InvalidCredentialsFailure>());
      expect(mapped.message, kInvalidCredentialsCopy);
      expect(mapped.debugDetail, raw);
      expect(mapped.message, isNot(contains(raw)));
    });

    test('wrong-password and user-not-found use the same plain copy', () {
      for (final code in ['wrong-password', 'user-not-found']) {
        final mapped = mapException(FirebaseException(
          plugin: 'firebase_auth',
          code: code,
          message: 'sdk message for $code',
        ));
        expect(mapped, isA<InvalidCredentialsFailure>());
        expect(mapped.message, kInvalidCredentialsCopy);
        expect(mapped.debugDetail, 'sdk message for $code');
      }
    });

    test('unknown code still falls through to UnknownFailure', () {
      final mapped = mapException(storage('quota-exceeded'));
      expect(mapped, isA<UnknownFailure>());
      expect(mapped.message, contains('quota-exceeded'));
    });

    test('an existing Failure passes through untouched', () {
      const f = MediaNotFoundFailure('gone');
      expect(identical(mapException(f), f), isTrue);
    });
  });
}
