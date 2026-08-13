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

/// Storage `retry-limit-exceeded` and Firestore/Auth connectivity codes.
///
/// **Types:** both map to [NetworkFailure], not [NetworkTimeoutFailure].
/// [NetworkTimeoutFailure] is Dart `TimeoutException` / [guardWithTimeout]
/// — the Future never completed. Native retry exhaustion and `unavailable`
/// are the SDK completing with an error. Collapsing them into
/// [NetworkTimeoutFailure] would flatten two mechanisms.
///
/// The hierarchy has no dedicated retry-exhausted member. Closest fit is
/// [NetworkFailure]. Not adding a new type this pass.
Failure _mapFirebaseException(FirebaseException e) {
  switch (e.code) {
    case 'retry-limit-exceeded':
    case 'unavailable':
    case 'deadline-exceeded':
    case 'network-request-failed':
      return NetworkFailure(e.message ?? e.code);
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
