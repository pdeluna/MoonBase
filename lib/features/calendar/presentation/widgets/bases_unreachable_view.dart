import 'package:flutter/material.dart';

/// Bug B-e (home half): the bases list errored. States the condition plainly
/// instead of showing the "create your first base" prompt.
class BasesUnreachableView extends StatelessWidget {
  const BasesUnreachableView({super.key, required this.onRetry});

  static const copy = 'Can\'t reach MoonBase right now.';
  static const detail = 'Showing what\'s saved on this device. '
      'Check Wi-Fi or mobile data and try again.';

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_outlined, size: 64, color: scheme.outline),
            const SizedBox(height: 24),
            Text(
              copy,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
