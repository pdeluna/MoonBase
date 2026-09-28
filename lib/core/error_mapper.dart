import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/either.dart';

Failure mapException(Object e) {
  if (e is Failure) return e;
  if (e is TimeoutException) return const NetworkTimeoutFailure();
  if (e is FirebaseException) return _mapFirebaseException(e);
  if (e is StateError || e is FormatException) {
    return const CacheFailure('Local data error');
  }
  return UnknownFailure(e.toString());
}

/// Auth codes that must not surface the Firebase sentence.
///
/// Returns null for codes this helper does not own (Storage, Firestore).
/// [sdkMessage] is kept as [Failure.debugDetail] or, for [NetworkFailure],
/// as the failure message the presenter already hides.
Failure? mapAuthFirebaseCode(String code, String? sdkMessage) {
  final raw = (sdkMessage == null || sdkMessage.isEmpty) ? code : sdkMessage;
  switch (code) {
    case 'network-request-failed':
    case 'too-many-requests':
      return NetworkFailure(raw);
    case 'wrong-password':
    case 'user-not-found':
    case 'invalid-credential':
      return InvalidCredentialsFailure(debugDetail: raw);
    case 'invalid-email':
      return ValidationFailure('Enter a valid email address.', raw);
    case 'user-disabled':
      return ValidationFailure('This account is turned off.', raw);
    case 'email-already-in-use':
      return ValidationFailure('That email is already in use.', raw);
    case 'weak-password':
      return ValidationFailure('Use at least 6 characters.', raw);
    default:
      return null;
  }
}

/// Storage `retry-limit-exceeded` and Firestore connectivity codes.
///
/// **Types:** both map to [NetworkFailure], not [NetworkTimeoutFailure].
/// [NetworkTimeoutFailure] is Dart `TimeoutException` / [guardWithTimeout]
/// — the Future never completed. Native retry exhaustion and `unavailable`
/// are the SDK completing with an error. Collapsing them into
/// [NetworkTimeoutFailure] would flatten two mechanisms.
///
/// The hierarchy has no dedicated retry-exhausted member. Closest fit is
/// [NetworkFailure]. Not adding a new type this pass.
///
/// **Storage / rules access codes (B-b):** `object-not-found` →
/// [MediaNotFoundFailure]; `unauthorized` / `unauthenticated` (Storage) and
/// `permission-denied` (Firestore) → [PermissionDeniedFailure]. These carry
/// authored copy, not the SDK message, because they reach the screen
/// directly (media tiles, rule-denied writes). Auth credential codes are
/// handled first by [mapAuthFirebaseCode].
Failure _mapFirebaseException(FirebaseException e) {
  final auth = mapAuthFirebaseCode(e.code, e.message);
  if (auth != null) return auth;
  switch (e.code) {
    case 'retry-limit-exceeded':
    case 'unavailable':
    case 'deadline-exceeded':
      return NetworkFailure(e.message ?? e.code);
    case 'object-not-found':
      return const MediaNotFoundFailure();
    case 'unauthorized':
    case 'unauthenticated':
    case 'permission-denied':
      return const PermissionDeniedFailure();
    default:
      return UnknownFailure(e.toString());
  }
}

Future<Either<Failure, T>> guard<T>(Future<T> Function() run) async {
  try {
    final v = await run();
    return Right(v);
  } catch (e) {
    return Left(mapException(e));
  }
}

/// Use this when your Right type is `void`.
Future<Either<Failure, void>> guardVoid(Future<void> Function() run) async {
  try {
    await run();
    return const Right(null);
  } catch (e) {
    return Left(mapException(e));
  }
}

/// Backstop against unbounded I/O waits, not a responsiveness target.
///
/// Six device measurements of `readProfile` — a Firestore document get
/// that succeeded from cache every time:
/// 63ms / 597ms / 10036ms / 10053ms / 14939ms / 14948ms.
///
/// Firestore's online-state tracker gives up at ~10.2s (measured
/// 10182 / 10217 / 10325), but the cached fallback can land well after
/// that transition — the 14.9s readings are the proof. An 8s or 15s
/// timeout would have converted successful cached reads into failures
/// with the data sitting on disk.
///
/// Responsiveness comes from R5 rendering cached chat at ~100ms
/// regardless of what a profile read is doing. This value only bounds
/// the wait if the Future never returns.
///
/// Per **call**, not per get. `guardWithTimeout` caps the whole `run`
/// closure. Callers that do two sequential Firestore gets under one
/// invocation (`getInviteByCode`, `getLastAccessedBase`) share this 20s.
/// A single cache fallback can land at 14.9s, so a legitimate pair could
/// exceed the budget. Acceptable for a backstop — do not assume each get
/// gets its own 20s.
const Duration kGuardTimeout = Duration(seconds: 20);

/// Same as [guard], with a [kGuardTimeout] cap on [run].
///
/// Sibling, not a default on [guard]: Pass 1 is opt-in. Baking 20s into
/// [guard] would change every existing caller — including `SendMessage` /
/// `ChatController.send()` — without a call-site diff. Pass 2 migrates
/// callers one at a time. The only `.timeout()` in this helper lives here.
Future<Either<Failure, T>> guardWithTimeout<T>(
  Future<T> Function() run,
) =>
    guard(() => run().timeout(kGuardTimeout));
