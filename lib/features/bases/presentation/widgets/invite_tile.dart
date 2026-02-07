import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moonbase_skeleton/features/bases/presentation/viewmodels/invite_tile_vm.dart';

class InviteTile extends StatelessWidget {
  const InviteTile({super.key, required this.vm, required this.onTap});

  final InviteTileVM vm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: vm.isExpired || vm.isDepleted
              ? Theme.of(context).colorScheme.errorContainer
              : Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            vm.isExpired || vm.isDepleted
                ? Icons.error_outline
                : Icons.check_circle_outline,
            color: vm.isExpired || vm.isDepleted
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          vm.code,
          style: TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            color: vm.isExpired || vm.isDepleted
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Created: ${_formatDate(vm.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (vm.maxUses != null)
              Text(
                'Used: ${vm.usedCount}/${vm.maxUses}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (vm.isExpired)
              Text(
                'Expired',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              )
            else if (vm.isDepleted)
              Text(
                'Used up',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'copy':
                Clipboard.setData(ClipboardData(text: vm.code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invite code copied to clipboard')),
                );
                break;
              case 'details':
                onTap();
                break;
            }
          },
          itemBuilder: (context) => [
            if (!vm.isExpired && !vm.isDepleted)
              const PopupMenuItem(
                value: 'copy',
                child: Row(
                  children: [
                    Icon(Icons.copy),
                    SizedBox(width: 8),
                    Text('Copy Code'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'details',
              child: Row(
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 8),
                  Text('View Details'),
                ],
              ),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
