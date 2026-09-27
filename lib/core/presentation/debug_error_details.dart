import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:moonbase_skeleton/core/presentation/failure_presenter.dart';

/// Developer-only error affordance: a hover tooltip with the raw
/// `runtimeType: message` and a long-press dialog with the full
/// [debugDescription] (type, raw `toString()`, stack).
///
/// [enabled] defaults to [kMoonbaseDebugUi]. [build] tests that const before
/// [enabled], so profile and release builds tree-shake the tooltip and
/// dialog; tests (where the const stays on) still pass `enabled: true/false`.
/// Wrap any error surface (snackbar body, inline error text, broken tile)
/// with this; it never changes layout.
class DebugErrorDetails extends StatelessWidget {
  const DebugErrorDetails({
    super.key,
    required this.error,
    required this.child,
    this.stackTrace,
    this.enabled = kMoonbaseDebugUi,
  });

  final Object? error;
  final StackTrace? stackTrace;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!kMoonbaseDebugUi || !enabled) return child;
    return Tooltip(
      message: debugSummary(error),
      // Manual: hover shows the tooltip on desktop/web; long-press is
      // reserved for the details dialog so the two never compete.
      triggerMode: TooltipTriggerMode.manual,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () => showDebugErrorDetails(
          context,
          error,
          stackTrace: stackTrace,
          enabled: enabled,
        ),
        child: child,
      ),
    );
  }
}

/// Opens the developer details dialog for [error]. No-op unless
/// [kMoonbaseDebugUi] and [enabled] (default [kMoonbaseDebugUi]). The const
/// is tested first so the dialog is absent from profile and release builds.
Future<void> showDebugErrorDetails(
  BuildContext context,
  Object? error, {
  StackTrace? stackTrace,
  bool enabled = kMoonbaseDebugUi,
}) {
  if (!kMoonbaseDebugUi || !enabled) return Future<void>.value();
  final description = debugDescription(error, stackTrace);
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Error details (debug build)'),
      content: SingleChildScrollView(
        child: SelectableText(
          description,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Clipboard.setData(ClipboardData(text: description)),
          child: const Text('Copy'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
