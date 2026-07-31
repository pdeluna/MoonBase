import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/features/bases/presentation/providers/sidebar_providers.dart';

class DeleteBaseDialog extends ConsumerWidget {
  const DeleteBaseDialog({super.key, required this.baseId, required this.baseName});

  final String baseId;
  final String baseName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: const Text('Delete Base'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Are you sure you want to delete "$baseName"?'),
          const SizedBox(height: 16),
          Text(
            'This action cannot be undone. All data including messages, invites, and member information will be permanently deleted.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            await _deleteBase(context, ref);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }

  Future<void> _deleteBase(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(deleteBaseProvider(baseId).future);

      ref.invalidate(basesListProvider);
      final selected = ref.read(selectedBaseProvider);
      if (selected?.id.value == baseId) {
        ref.read(selectedBaseProvider.notifier).state = null;
      }

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Base deleted successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete base: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
