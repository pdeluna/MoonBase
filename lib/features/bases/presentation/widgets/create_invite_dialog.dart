import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/features/bases/presentation/providers/invite_providers.dart';
import 'package:moonbase_skeleton/features/bases/domain/usecases/create_invite.dart';
import 'package:moonbase_skeleton/features/auth/presentation/providers/current_user_id_provider.dart';
import 'package:moonbase_skeleton/core/ids.dart';

class CreateInviteDialog extends ConsumerStatefulWidget {
  const CreateInviteDialog({super.key, required this.baseId});

  final String baseId;

  @override
  ConsumerState<CreateInviteDialog> createState() => _CreateInviteDialogState();
}

class _CreateInviteDialogState extends ConsumerState<CreateInviteDialog> {
  final _maxUsesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _maxUsesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
              await _createInvite();
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _createInvite() async {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not authenticated')),
        );
      }
      return;
    }

    try {
      final maxUses = _maxUsesController.text.isNotEmpty 
          ? int.parse(_maxUsesController.text) 
          : null;

      final params = CreateInviteParams(
        baseId: widget.baseId.bid,
        createdByUserId: currentUserId.uid,
        maxUses: maxUses,
      );

      final invite = await ref.read(createInviteProvider(params).future);

      if (!mounted) return;
      if (invite == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create invite')),
        );
        return;
      }

      ref.invalidate(baseInvitesProvider(widget.baseId));
      Navigator.of(context).pop(); // close create form only after success
      _showInviteCodeDialog(invite.code);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create invite: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showInviteCodeDialog(String code) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite Created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Your invite code is:'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    code,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invite code copied to clipboard')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy code',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Share this code with others to invite them to your base.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
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
}
