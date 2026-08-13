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
}
