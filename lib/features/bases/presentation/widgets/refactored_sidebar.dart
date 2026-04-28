import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/features/bases/domain/entities/base.dart';
import 'package:moonbase_skeleton/features/bases/presentation/providers/sidebar_providers.dart';
import 'package:moonbase_skeleton/features/bases/presentation/viewmodels/sidebar_vm.dart';
import 'package:moonbase_skeleton/features/bases/presentation/widgets/base_tile.dart';
import 'package:moonbase_skeleton/features/bases/presentation/widgets/create_base_dialog.dart';
import 'package:moonbase_skeleton/features/bases/presentation/widgets/join_base_dialog.dart';
import 'package:moonbase_skeleton/features/bases/presentation/widgets/update_base_dialog.dart';
import 'package:moonbase_skeleton/features/bases/presentation/widgets/delete_base_dialog.dart';
import 'package:moonbase_skeleton/legacy/widgets/moon_spinner.dart';

class RefactoredSidebar extends ConsumerWidget {
  const RefactoredSidebar({
    super.key,
    this.onBaseSelected,
    this.onCreateBase,
    this.onJoinBase,
  });
  
  final VoidCallback? onBaseSelected;
  final VoidCallback? onCreateBase;
  final VoidCallback? onJoinBase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sidebarVm = ref.watch(sidebarVmProvider);

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        children: [
          // Safe area for status bar
          SafeArea(
            bottom: false,
            child: Container(
              height: 0,
            ),
          ),
          
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.home_work_outlined,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'My Bases',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Switch between your bases',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),

          // Current Base Section
          if (sidebarVm.selectedBase != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Base',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(
                          sidebarVm.selectedBase!.name[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sidebarVm.selectedBase!.name,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSecondaryContainer,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Bases List
          Expanded(
            child: _buildBasesContent(context, ref, sidebarVm),
          ),

          // Action Buttons
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showCreateBaseDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Create Base'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showJoinBaseDialog(context),
                      icon: const Icon(Icons.group_add),
                      label: const Text('Join Base'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasesContent(BuildContext context, WidgetRef ref, SidebarVM sidebarVm) {
    if (sidebarVm.isLoading) {
      return const Center(child: MoonSpinner());
    }
    
    if (sidebarVm.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading bases',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                sidebarVm.errorMessage ?? 'Unknown error',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.refresh(basesListProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    
    if (sidebarVm.isEmpty) {
      return _buildEmptyState(context);
    }
    
    return _buildBasesList(context, ref, sidebarVm.bases);
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.home_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 24),
            Text(
              'No bases yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Create your first base to start sharing with your circle',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasesList(BuildContext context, WidgetRef ref, List<Base> bases) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: bases.length,
      itemBuilder: (context, index) {
        final base = bases[index];
        return BaseTile(
          key: ValueKey(base.id.value),
          baseId: base.id.value,
          onTap: onBaseSelected,
          onLongPress: () => _showBaseOptions(context, base),
        );
      },
    );
  }

  void _showCreateBaseDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => const CreateBaseDialog(),
    );
  }

  void _showJoinBaseDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => const JoinBaseDialog(),
    );
  }

  void _showBaseOptions(BuildContext context, Base base) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Base Options',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Update Base'),
              subtitle: Text('Change the name and description of "${base.name}"'),
              onTap: () {
                Navigator.of(context).pop();
                _showUpdateDialog(context, base);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Base', style: TextStyle(color: Colors.red)),
              subtitle: const Text('Permanently delete this base and all its data'),
              onTap: () {
                Navigator.of(context).pop();
                _showDeleteDialog(context, base);
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateDialog(BuildContext context, Base base) {
    showDialog<void>(
      context: context,
      builder: (context) => UpdateBaseDialog(
        baseId: base.id.value,
        currentName: base.name,
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Base base) {
    showDialog<void>(
      context: context,
      builder: (context) => DeleteBaseDialog(
        baseId: base.id.value,
        baseName: base.name,
      ),
    );
  }
}
