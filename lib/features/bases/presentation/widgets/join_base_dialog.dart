import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/validators.dart';
import 'package:moonbase_skeleton/features/auth/presentation/providers/current_user_id_provider.dart';
import 'package:moonbase_skeleton/features/bases/presentation/providers/base_providers.dart';
import 'package:moonbase_skeleton/features/bases/presentation/providers/sidebar_providers.dart';

class JoinBaseDialog extends ConsumerStatefulWidget {
  const JoinBaseDialog({super.key});

  @override
  ConsumerState<JoinBaseDialog> createState() => _JoinBaseDialogState();
}

class _JoinBaseDialogState extends ConsumerState<JoinBaseDialog> {
  final _inviteCodeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _inviteCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Join Base'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _inviteCodeController,
              decoration: const InputDecoration(
                labelText: 'Invite Code',
                hintText: 'Enter 6-character code',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an invite code';
                }
                final normalizedCode = normalizeInviteCode(value);
                if (!isValidInviteCode(normalizedCode)) {
                  return 'Invalid invite code (6 chars, A–Z & 2–9)';
                }
                return null;
              },
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
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
              await _joinBase();
            }
          },
          child: const Text('Join'),
        ),
      ],
    );
  }

  Future<void> _joinBase() async {
    try {
      final base = await ref.read(
        joinBaseWithCodeProvider(_inviteCodeController.text.trim()).future,
      );
      if (!mounted) return;

      ref.invalidate(basesListProvider);
      if (base != null) {
        ref.read(selectedBaseProvider.notifier).state = base;
        final currentUserId = ref.read(currentUserIdProvider);
        if (currentUserId != null) {
          await ref.read(baseRepositoryProvider).setLastAccessedBase(
                userId: UserId(currentUserId),
                baseId: base.id,
              );
          ref.invalidate(lastAccessedBaseProvider);
        }
      }
      if (!mounted) return;

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully joined base!')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join base: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
