import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moonbase_skeleton/legacy/models/invite.dart';
import 'package:moonbase_skeleton/legacy/providers/invites_provider.dart';
import 'package:moonbase_skeleton/legacy/providers/bases_provider.dart';
import 'package:moonbase_skeleton/legacy/widgets/moon_spinner.dart';

class InvitesScreen extends ConsumerStatefulWidget {
  const InvitesScreen({super.key});

  @override
  ConsumerState<InvitesScreen> createState() => _InvitesScreenState();
}

class _InvitesScreenState extends ConsumerState<InvitesScreen> {
  final _maxUsesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _maxUsesController.dispose();
    super.dispose();
  }

  void _showCreateInviteDialog() {
    _maxUsesController.clear();
    
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Invite'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _maxUsesController,
                decoration: const InputDecoration(
                  labelText: 'Max Uses (Optional)',
                  hintText: 'Leave empty for unlimited',
                  helperText: 'Number of times this invite can be used',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final maxUses = int.tryParse(value);
                    if (maxUses == null || maxUses <= 0) {
                      return 'Please enter a valid number greater than 0';
                    }
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                Navigator.of(context).pop();
                await _createInvite();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createInvite() async {
    final selectedBase = ref.read(effectiveSelectedBaseProvider);
    if (selectedBase == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a base first')),
      );
      return;
    }

    try {
      final maxUses = _maxUsesController.text.isNotEmpty 
          ? int.parse(_maxUsesController.text) 
          : null;

      final invite = await ref.read(invitesProvider.notifier).createInvite(
        baseId: selectedBase.id,
        maxUses: maxUses,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invite created: ${invite.code}'),
            action: SnackBarAction(
              label: 'Copy',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: invite.code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invite code copied to clipboard')),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create invite: $e')),
        );
      }
    }
  }

  void _showInviteDetails(BaseInvite invite) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Code', invite.code),
            _buildDetailRow('Created', _formatDate(invite.createdAt)),
            if (invite.expiresAt != null)
              _buildDetailRow('Expires', _formatDate(invite.expiresAt!)),
            _buildDetailRow('Max Uses', invite.maxUses?.toString() ?? 'Unlimited'),
            _buildDetailRow('Used', '${invite.usedCount} times'),
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
                    invite.isExpired || invite.isDepleted 
                        ? Icons.error_outline 
                        : Icons.check_circle_outline,
                    color: invite.isExpired || invite.isDepleted 
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      invite.isExpired 
                          ? 'This invite has expired'
                          : invite.isDepleted
                              ? 'This invite has been used up'
                              : 'This invite is active',
                      style: TextStyle(
                        color: invite.isExpired || invite.isDepleted 
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
          if (!invite.isExpired && !invite.isDepleted)
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: invite.code));
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invite code copied to clipboard')),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy Code'),
            ),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
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
            child: Consumer(
              builder: (context, ref, child) {
                final invitesAsync = ref.watch(baseInvitesProvider(selectedBase.id));
                
                return invitesAsync.when(
                  loading: () => const Center(child: MoonSpinner()),
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
                      ? _buildEmptyState() 
                      : _buildInvitesList(invites),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateInviteDialog,
        icon: const Icon(Icons.add),
        label: const Text('Create Invite'),
      ),
    );
  }

  Widget _buildEmptyState() {
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
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showCreateInviteDialog,
            icon: const Icon(Icons.add),
            label: const Text('Create Invite'),
          ),
        ],
      ),
    );
  }

  Widget _buildInvitesList(List<BaseInvite> invites) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: invites.length,
      itemBuilder: (context, index) {
        final invite = invites[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: invite.isExpired || invite.isDepleted
                  ? Theme.of(context).colorScheme.errorContainer
                  : Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                invite.isExpired || invite.isDepleted
                    ? Icons.error_outline
                    : Icons.check_circle_outline,
                color: invite.isExpired || invite.isDepleted
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
            title: Text(
              invite.code,
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                color: invite.isExpired || invite.isDepleted
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Created: ${_formatDate(invite.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (invite.maxUses != null)
                  Text(
                    'Used: ${invite.usedCount}/${invite.maxUses}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (invite.isExpired)
                  Text(
                    'Expired',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  )
                else if (invite.isDepleted)
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
                    Clipboard.setData(ClipboardData(text: invite.code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invite code copied to clipboard')),
                    );
                    break;
                  case 'details':
                    _showInviteDetails(invite);
                    break;
                }
              },
              itemBuilder: (context) => [
                if (!invite.isExpired && !invite.isDepleted)
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
            onTap: () => _showInviteDetails(invite),
          ),
        );
      },
    );
  }
}
