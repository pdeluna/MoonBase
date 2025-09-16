import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moonbase_skeleton/features/bases/presentation/viewmodels/invite_tile_vm.dart';

class InviteDetailsDialog extends StatelessWidget {
  const InviteDetailsDialog({super.key, required this.vm});

  final InviteTileVM vm;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invite Details'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Code', vm.code),
          _buildDetailRow('Created', _formatDate(vm.createdAt)),
          if (vm.expiresAt != null)
            _buildDetailRow('Expires', _formatDate(vm.expiresAt!)),
          _buildDetailRow('Max Uses', vm.maxUses?.toString() ?? 'Unlimited'),
          _buildDetailRow('Used', '${vm.usedCount} times'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  vm.isExpired || vm.isDepleted 
                      ? Icons.error_outline 
                      : Icons.check_circle_outline,
                  color: vm.isExpired || vm.isDepleted 
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    vm.isExpired 
                        ? 'This invite has expired'
                        : vm.isDepleted
                            ? 'This invite has been used up'
                            : 'This invite is active',
                    style: TextStyle(
                      color: vm.isExpired || vm.isDepleted 
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (!vm.isExpired && !vm.isDepleted)
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: vm.code));
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invite code copied to clipboard')),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy Code'),
          ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
