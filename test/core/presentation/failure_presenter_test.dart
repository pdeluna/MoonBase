import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/presentation/failure_presenter.dart';

void main() {
  group('kMoonbaseDebugUi', () {
    test('is a compile-time constant that is never on outside kDebugMode', () {
      // In `flutter test` kDebugMode is true, so the define default applies.
      expect(kMoonbaseDebugUi, kDebugMode);
    });
  });

  group('userMessage — Failure subtypes', () {
    test('NetworkFailure → fixed plain copy, SDK message hidden', () {
      expect(
        userMessage(const NetworkFailure('retry-limit-exceeded')),
        kNetworkErrorCopy,
      );
    });

    test('NetworkTimeoutFailure → fixed timeout copy', () {
      expect(userMessage(const NetworkTimeoutFailure()), kNetworkTimeoutCopy);
    });

    test('CacheFailure → fixed cache copy', () {
      expect(
        userMessage(const CacheFailure('Local data error')),
        kCacheErrorCopy,
      );
    });

    test('ValidationFailure → authored message verbatim', () {
      expect(
        userMessage(const ValidationFailure('Invalid email or password.')),
        'Invalid email or password.',
      );
    });

    test('PermissionDeniedFailure / UnauthenticatedFailure → message', () {
      expect(
        userMessage(const PermissionDeniedFailure()),
        'Permission denied.',
      );
      expect(
        userMessage(const UnauthenticatedFailure()),
        'You need to be signed in to do that.',
      );
    });

    test('media failures → authored message', () {
      expect(
        userMessage(const MediaTooLargeFailure()),
        'Media exceeds the maximum size.',
      );
      expect(
        userMessage(const MediaUnsupportedFailure('HEIC is not supported.')),
        'HEIC is not supported.',
      );
    });

    test('UnknownFailure default → generic copy', () {
      expect(userMessage(const UnknownFailure()), kGenericErrorCopy);
    });

    test('UnknownFailure wrapping Exception.toString() → prefix stripped', () {
      expect(
        userMessage(const UnknownFailure('Exception: Base not found')),
        'Base not found',
      );
    });

    test('UnknownFailure wrapping FirebaseException.toString() → code stripped',
        () {
      expect(
        userMessage(const UnknownFailure(
          '[cloud_firestore/permission-denied] '
          'The caller does not have permission to execute the operation.',
        )),
        'The caller does not have permission to execute the operation.',
      );
    });

    test('empty authored message never yields empty copy', () {
      expect(userMessage(const ValidationFailure('')), kGenericErrorCopy);
      expect(userMessage(const ValidationFailure('   ')), kGenericErrorCopy);
    });
  });

  group('userMessage — non-Failure objects', () {
    test('Exception(x) → x, no "Exception:" leak', () {
      expect(userMessage(Exception('Only base owner can delete the base')),
          'Only base owner can delete the base');
    });

    test('StateError → "Bad state:" stripped', () {
      expect(userMessage(StateError('boom')), 'boom');
    });

    test('ArgumentError → "Invalid argument(s):" stripped', () {
      expect(userMessage(ArgumentError('bad arg')), 'bad arg');
    });

    test('FormatException → prefix stripped', () {
      expect(userMessage(const FormatException('nope')), 'nope');
    });

    test('plain String passes through', () {
      expect(userMessage('Already a member.'), 'Already a member.');
    });

    test('null → generic copy', () {
      expect(userMessage(null), kGenericErrorCopy);
    });

    test('Exception with empty message → generic copy', () {
      expect(userMessage(Exception()), kGenericErrorCopy);
    });
  });

  group('stripExceptionPrefix', () {
    test('collapses nested prefixes', () {
      expect(
        stripExceptionPrefix('Exception: Exception: nested'),
        'nested',
      );
      expect(
        stripExceptionPrefix(
          'Exception: [firebase_storage/object-not-found] Missing',
        ),
        'Missing',
      );
    });

    test('leaves text without a prefix untouched', () {
      expect(stripExceptionPrefix('Hello: world'), 'Hello: world');
    });
  });

  group('debugSummary / debugDescription', () {
    test('summary is runtimeType plus message', () {
      expect(
        debugSummary(const NetworkFailure('unavailable')),
        'NetworkFailure: unavailable',
      );
      // Runtime type of a plain Exception is the private `_Exception`.
      expect(debugSummary(Exception('x')), endsWith('Exception: Exception: x'));
      expect(debugSummary(null), 'null');
    });

    test('description carries type, user copy, raw and stack', () {
      final trace = StackTrace.fromString('#0 main (file.dart:1:1)');
      final d = debugDescription(const ValidationFailure('Bad input'), trace);
      expect(d, contains('type: ValidationFailure'));
      expect(d, contains('user copy: Bad input'));
      expect(d, contains('failure message: Bad input'));
      expect(d, contains('raw: ValidationFailure(Bad input)'));
      expect(d, contains('#0 main (file.dart:1:1)'));
    });

    test('description omits stack section when none captured', () {
      final d = debugDescription(Exception('x'));
      expect(d, isNot(contains('stack:')));
      expect(d, contains('type: _Exception'));
    });
  });
}
