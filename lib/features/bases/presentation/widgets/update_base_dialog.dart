import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/features/bases/presentation/providers/sidebar_providers.dart';
import 'package:moonbase_skeleton/features/bases/domain/usecases/update_base.dart';
import 'package:moonbase_skeleton/features/auth/presentation/providers/current_user_id_provider.dart';
import 'package:moonbase_skeleton/core/ids.dart';
import 'package:moonbase_skeleton/core/validators.dart';

class UpdateBaseDialog extends ConsumerStatefulWidget {
  const UpdateBaseDialog({super.key, required this.baseId, required this.currentName});

  final String baseId;
  final String currentName;

  @override
  ConsumerState<UpdateBaseDialog> createState() => _UpdateBaseDialogState();
}

class _UpdateBaseDialogState extends ConsumerState<UpdateBaseDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update Base'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Base Name',
                hintText: 'Enter base name',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Base name is required';
                }
                if (!isValidBaseName(value.trim())) {
                  return 'Base name must be 1–32 characters';
                }
                return null;
              },
              autofocus: true,
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
              await _updateBase();
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _updateBase() async {
    try {
      final currentUserId = ref.read(currentUserIdProvider);
      if (currentUserId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not authenticated')),
          );
        }
        return;
      }

      final params = UpdateBaseParams(
        baseId: widget.baseId.bid,
        name: _nameController.text.trim(),
        requesterUserId: currentUserId.uid,
      );
      
      await ref.read(updateBaseProvider(params).future);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Base updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update base: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
