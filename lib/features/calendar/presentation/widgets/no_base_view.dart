import 'package:flutter/material.dart';
import 'package:moonbase_skeleton/features/bases/presentation/widgets/create_base_dialog.dart';
import 'package:moonbase_skeleton/features/bases/presentation/widgets/join_base_dialog.dart';
import 'package:moonbase_skeleton/legacy/widgets/primary_button.dart';

/// Bases loaded but none is selected. Shown **only** for `data(...)` — never
/// while loading or errored (bug B-e).
class NoBaseView extends StatelessWidget {
  const NoBaseView({super.key, required this.hasBases});

  static const noBasesTitle = 'No Base Available';
  static const noBasesBody =
      'Create your first base to start sharing with your circle';
  static const pickTitle = 'No base selected';
  static const pickBody =
      'Swipe right to pick one of your bases, or create a new one';

  /// True when the user belongs to bases but none is selected.
  final bool hasBases;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_work_outlined, size: 64, color: scheme.outline),
            const SizedBox(height: 24),
            Text(
              hasBases ? pickTitle : noBasesTitle,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              hasBases ? pickBody : noBasesBody,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            PrimaryButton(
              label: 'Create Base',
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => const CreateBaseDialog(),
              ),
              filled: true,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => const JoinBaseDialog(),
              ),
              icon: const Icon(Icons.group_add, size: 20),
              label: const Text('Join Base'),
            ),
          ],
        ),
      ),
    );
  }
}
