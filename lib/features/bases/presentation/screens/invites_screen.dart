import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moonbase_skeleton/features/bases/presentation/widgets/invite_list.dart';
import 'package:moonbase_skeleton/features/bases/presentation/widgets/create_invite_dialog.dart';
import 'package:moonbase_skeleton/providers/bases_provider.dart';

class InvitesScreen extends ConsumerWidget {
  const InvitesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedBase = ref.watch(effectiveSelectedBaseProvider);

    if (selectedBase == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Invites'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home'),
          ),
        ),
        body: const Center(
          child: Text('Please select a base to manage invites'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Invites - ${selectedBase.name}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: Column(
        children: [
          // Header with base info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Base Invites',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Create and manage invite codes for ${selectedBase.name}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),

          // Invites list
          Expanded(
            child: InviteList(baseId: selectedBase.id),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateInviteDialog(context, selectedBase.id),
        icon: const Icon(Icons.add),
        label: const Text('Create Invite'),
      ),
    );
  }

  void _showCreateInviteDialog(BuildContext context, String baseId) {
    showDialog<void>(
      context: context,
      builder: (context) => CreateInviteDialog(baseId: baseId),
    );
  }
}
