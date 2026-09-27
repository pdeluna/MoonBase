import 'package:flutter/material.dart';

/// Neutral placeholder while bases or the feed load — deliberately carries no
/// copy so a slow network never reads as "you have nothing" (bug B-e).
class CalendarLoadingSkeleton extends StatelessWidget {
  const CalendarLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context)
        .colorScheme
        .surfaceContainerHighest
        .withValues(alpha: 0.6);
    Widget bar(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
        );
    return Semantics(
      label: 'Loading',
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          bar(220, 14),
          const SizedBox(height: 20),
          for (var i = 0; i < 3; i++) ...[
            bar(160, 12),
            const SizedBox(height: 10),
            bar(double.infinity, 64),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}
