import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/features/bases/presentation/providers/invite_providers.dart';
import 'package:moonbase_skeleton/features/bases/presentation/widgets/invite_tile.dart';
import 'package:moonbase_skeleton/features/bases/presentation/widgets/invite_details_dialog.dart';
import 'package:moonbase_skeleton/features/bases/presentation/viewmodels/invite_tile_vm.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/invite.dart';

class InviteList extends ConsumerWidget {
  const InviteList({super.key, required this.baseId});

  final String baseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitesAsync = ref.watch(baseInvitesProvider(baseId));
    
    return invitesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading invites',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      data: (invites) => invites.isEmpty 
          ? _buildEmptyState(context) 
          : _buildInvitesList(context, invites),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_add_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No invites yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first invite to share this base',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInvitesList(BuildContext context, List<Invite> invites) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: invites.length,
      itemBuilder: (context, index) {
        final invite = invites[index];
        final vm = InviteTileVM.fromInvite(invite);
        return InviteTile(
          vm: vm,
          onTap: () => _showInviteDetails(context, vm),
        );
      },
    );
  }

  void _showInviteDetails(BuildContext context, InviteTileVM vm) {
    showDialog<void>(
      context: context,
      builder: (context) => InviteDetailsDialog(vm: vm),
    );
  }
}
