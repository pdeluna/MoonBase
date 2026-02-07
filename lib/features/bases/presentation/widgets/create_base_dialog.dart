import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/features/bases/presentation/providers/sidebar_providers.dart';
import 'package:moonbase_skeleton/core/validators.dart';

class CreateBaseDialog extends ConsumerStatefulWidget {
  const CreateBaseDialog({super.key});

  @override
  ConsumerState<CreateBaseDialog> createState() => _CreateBaseDialogState();
}

class _CreateBaseDialogState extends ConsumerState<CreateBaseDialog> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Base'),
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
                  return 'Please enter a base name';
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
              await _createBase();
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _createBase() async {
    try {
      final base = await ref.read(createBaseProvider(_nameController.text.trim()).future);
      ref.invalidate(basesListProvider);
      if (base != null) {
        ref.read(selectedBaseProvider.notifier).state = base;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Base created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create base: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
