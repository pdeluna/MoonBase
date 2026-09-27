import 'package:flutter/material.dart';

import 'package:moonbase_skeleton/core/presentation/debug_error_details.dart';
import 'package:moonbase_skeleton/core/presentation/failure_presenter.dart';

/// How long an error snackbar stays up. Longer than the 4s default so a
/// multi-line message can actually be read.
const Duration kFailureSnackBarDuration = Duration(seconds: 6);

/// Shows [error] as a plain-copy, multi-line error snackbar.
///
/// - Copy comes from [userMessage] — never `toString()`, never truncated
///   (no `maxLines`; the snackbar grows to fit).
/// - [prefix] names the operation, e.g. `'Could not create base'` →
///   `Could not create base: <copy>`.
/// - [onRetry] adds a **Retry** action.
/// - When [showDebugDetails] (default [kMoonbaseDebugUi], `false` outside
///   `kDebugMode`) the body is long-pressable for the raw details dialog and,
///   if there is no retry action, a **Details** action is added.
///
/// Replaces any snackbar currently showing so errors never queue behind
/// success toasts.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showFailureSnackBar(
  BuildContext context,
  Object? error, {
  StackTrace? stackTrace,
  String? prefix,
  VoidCallback? onRetry,
  bool showDebugDetails = kMoonbaseDebugUi,
}) {
  final scheme = Theme.of(context).colorScheme;
  final copy = userMessage(error);
  final text = prefix == null || prefix.isEmpty ? copy : '$prefix: $copy';

  final SnackBarAction? action;
  if (onRetry != null) {
    action = SnackBarAction(
      label: 'Retry',
      textColor: scheme.onError,
      onPressed: onRetry,
    );
  } else if (showDebugDetails) {
    action = SnackBarAction(
      label: 'Details',
      textColor: scheme.onError,
      onPressed: () {
        if (!context.mounted) return;
        showDebugErrorDetails(
          context,
          error,
          stackTrace: stackTrace,
          enabled: showDebugDetails,
        );
      },
    );
  } else {
    action = null;
  }

  final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  return messenger.showSnackBar(
    SnackBar(
      duration: kFailureSnackBarDuration,
      backgroundColor: scheme.error,
      content: DebugErrorDetails(
        error: error,
        stackTrace: stackTrace,
        enabled: showDebugDetails,
        child: Text(
          text,
          style: TextStyle(color: scheme.onError),
        ),
      ),
      action: action,
    ),
  );
}
