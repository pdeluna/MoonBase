import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/features/auth/presentation/providers/current_user_id_provider.dart';
import 'package:moonbase_skeleton/features/bases/presentation/providers/sidebar_providers.dart';
import 'package:moonbase_skeleton/features/bases/presentation/providers/base_providers.dart';

class BaseTile extends ConsumerWidget {
  const BaseTile({super.key, required this.baseId, this.onTap, this.onLongPress});

  final String baseId;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(baseTileVmProvider(baseId));
    
    if (vm == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: vm.isSelected ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: vm.isSelected
            ? BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              )
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: vm.isSelected
              ? Theme.of(context).colorScheme.primary
              : vm.avatarColor,
          child: Text(
            vm.name[0].toUpperCase(),
            style: TextStyle(
              color: vm.isSelected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        title: Text(
          vm.name,
          style: TextStyle(
            fontWeight: vm.isSelected ? FontWeight.bold : FontWeight.normal,
            color: vm.isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: vm.isOwner
            ? Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Owner',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            : null,
        trailing: vm.isSelected
            ? Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              )
            : const Icon(Icons.chevron_right),
        onTap: () {
          // Find the base and select it
          final sidebarVm = ref.read(sidebarVmProvider);
          try {
            final base = sidebarVm.bases.firstWhere((b) => b.id.value == baseId);
            ref.read(selectedBaseProvider.notifier).state = base;

            final currentUserId = ref.read(currentUserIdProvider);
            if (currentUserId != null) {
              final baseRepository = ref.read(baseRepositoryProvider);
              baseRepository.setLastAccessedBase(
                userId: UserId(currentUserId),
                baseId: base.id,
              );
            }

            onTap?.call();
          } catch (e) {
            // Base not found
          }
        },
        onLongPress: vm.isOwner ? onLongPress : null,
      ),
    );
  }
}
