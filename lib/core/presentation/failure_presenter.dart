import 'package:flutter/foundation.dart';

import 'package:moonbase_skeleton/core/failure.dart';

/// Compile-time gate for developer-only error UI (details dialog, raw
/// tooltips — see `debug_error_details.dart`).
///
/// `kDebugMode` only: profile and release builds are never "developer builds"
/// (plan U-9). A debug build can opt out with
/// `--dart-define=MOONBASE_DEBUG_UI=false`. This is a `const`, so release and
/// profile builds tree-shake every branch guarded by it — same pattern as
/// `firebase_debug_harness.dart`. Never a runtime toggle, never persisted.
const bool kMoonbaseDebugUi =
    kDebugMode && bool.fromEnvironment('MOONBASE_DEBUG_UI', defaultValue: true);

/// Fallback copy when nothing better is known about the error.
const String kGenericErrorCopy = 'Something went wrong. Please try again.';

/// Copy for [NetworkFailure] — the SDK completed with a connectivity error.
const String kNetworkErrorCopy =
    "Can't reach MoonBase right now. Check Wi-Fi or mobile data and try again.";

/// Copy for [NetworkTimeoutFailure] — a guarded call never completed.
const String kNetworkTimeoutCopy =
    'MoonBase took too long to respond. Check your connection and try again.';

/// Copy for [CacheFailure] — local persistence could not be read/written.
const String kCacheErrorCopy =
    'Could not read saved data on this device. Please try again.';

/// Plain, complete, user-facing copy for any surfaced error.
///
/// The single place that decides what a user reads when an operation fails:
///
/// - [Failure] subtypes with SDK-shaped messages ([NetworkFailure],
///   [NetworkTimeoutFailure], [CacheFailure]) get fixed plain copy — their
///   `message` is typically a Firebase code or a Dart exception string.
/// - [UnknownFailure] carries `e.toString()` from `mapException`; the
///   `Exception:` / `[plugin/code]` noise is stripped and an empty or default
///   message falls back to [kGenericErrorCopy].
/// - Every other [Failure] (validation, permission, media caps, …) already
///   carries authored copy, so `message` is returned as-is.
/// - Non-[Failure] objects (a raw `Exception('x')`, a `StateError`) have
///   their type prefix stripped so no `Exception:` leaks to the screen.
///
/// Never returns an empty string.
String userMessage(Object? error) {
  if (error == null) return kGenericErrorCopy;
  if (error is Failure) return _failureCopy(error);
  return _orGeneric(stripExceptionPrefix(error.toString()));
}

String _failureCopy(Failure failure) {
  switch (failure) {
    case NetworkTimeoutFailure():
      return kNetworkTimeoutCopy;
    case NetworkFailure():
      return kNetworkErrorCopy;
    case CacheFailure():
      return kCacheErrorCopy;
    case UnknownFailure():
      final cleaned = stripExceptionPrefix(failure.message);
      return cleaned == 'Unknown error'
          ? kGenericErrorCopy
          : _orGeneric(cleaned);
    default:
      return _orGeneric(failure.message.trim());
  }
}

String _orGeneric(String s) => s.isEmpty ? kGenericErrorCopy : s;

final RegExp _exceptionPrefix = RegExp(
  r'^(?:Exception|Bad state|Invalid argument\(s\)|FormatException|'
  r'StateError|ArgumentError|TimeoutException|Unsupported operation|'
  r'UnimplementedError|Error|[A-Za-z]+(?:Exception|Error))\s*:\s*',
);

/// `[cloud_firestore/permission-denied] ` style prefix from
/// `FirebaseException.toString()`.
final RegExp _firebaseCodePrefix = RegExp(r'^\[[a-z_]+/[a-z\-]+\]\s*');

/// Removes Dart/Firebase exception decorations from a raw error string.
///
/// `Exception: Boom` → `Boom`; `[cloud_firestore/unavailable] Offline` →
/// `Offline`. Applied repeatedly so nested prefixes collapse. Visible for
/// testing.
String stripExceptionPrefix(String raw) {
  var s = raw.trim();
  for (var i = 0; i < 3; i++) {
    final next = s
        .replaceFirst(_exceptionPrefix, '')
        .replaceFirst(_firebaseCodePrefix, '')
        .trim();
    if (next == s) break;
    s = next;
  }
  // `Exception()` with no message prints just its type name — no copy there.
  if (_bareTypeName.hasMatch(s)) return '';
  return s;
}

final RegExp _bareTypeName = RegExp(r'^_?[A-Za-z]*(?:Exception|Error)$');

/// One-line developer summary: `NetworkFailure: Network error`.
String debugSummary(Object? error) {
  if (error == null) return 'null';
  if (error is Failure) return '${error.runtimeType}: ${error.message}';
  return '${error.runtimeType}: $error';
}

/// Multi-line developer description for the debug details dialog.
///
/// Raw, untouched material: runtime type, `toString()`, the [Failure]
/// message where applicable, and the stack trace when one was captured.
String debugDescription(Object? error, [StackTrace? stackTrace]) {
  final buffer = StringBuffer()
    ..writeln('type: ${error?.runtimeType ?? 'null'}')
    ..writeln('user copy: ${userMessage(error)}');
  if (error is Failure) buffer.writeln('failure message: ${error.message}');
  buffer.writeln('raw: $error');
  if (stackTrace != null) {
    buffer
      ..writeln()
      ..writeln('stack:')
      ..write(stackTrace);
  }
  return buffer.toString().trimRight();
}
