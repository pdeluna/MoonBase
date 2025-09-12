import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moonbase_skeleton/models/base.dart';
import 'package:moonbase_skeleton/providers/bases_provider.dart';
import 'package:moonbase_skeleton/widgets/primary_button.dart';
import 'package:moonbase_skeleton/widgets/moon_spinner.dart';

class BasePickerScreen extends ConsumerStatefulWidget {
  const BasePickerScreen({super.key});

  @override
  ConsumerState<BasePickerScreen> createState() => _BasePickerScreenState();
}

class _BasePickerScreenState extends ConsumerState<BasePickerScreen> {
  final _baseNameController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _baseNameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  void _showCreateBaseDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Base'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _baseNameController,
                decoration: const InputDecoration(
                  labelText: 'Base Name',
                  hintText: 'Enter base name',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a base name';
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
                await _createBase();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showJoinBaseDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
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
                  hintText: 'Enter invite code',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an invite code';
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
                await _joinBase();
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  Future<void> _createBase() async {
    try {
      await ref.read(basesProvider.notifier).createBase(
        name: _baseNameController.text.trim(),
      );
      _baseNameController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Base created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create base: $e')),
        );
      }
    }
  }

  Future<void> _joinBase() async {
    try {
      // TODO: Implement join base via invite code
      // This will need to be implemented in the bases provider
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Join base functionality coming soon!')),
      );
      _inviteCodeController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join base: $e')),
        );
      }
    }
  }

  void _switchBase(Base base) {
    ref.read(selectedBaseProvider.notifier).selectBase(base);
    if (mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final basesAsync = ref.watch(basesProvider);
    final selectedBase = ref.watch(effectiveSelectedBaseProvider);

         return Scaffold(
       appBar: AppBar(
         title: const Text('Base Picker'),
         leading: IconButton(
           icon: const Icon(Icons.arrow_back),
           onPressed: () => context.go('/home'),
         ),
       ),
       bottomNavigationBar: Container(
         padding: const EdgeInsets.all(16),
         decoration: BoxDecoration(
           color: Theme.of(context).scaffoldBackgroundColor,
           border: Border(
             top: BorderSide(
               color: Theme.of(context).dividerColor,
               width: 0.5,
             ),
           ),
         ),
         child: SafeArea(
           child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               PrimaryButton(
                 label: 'Create Base',
                 onPressed: _showCreateBaseDialog,
                 filled: true,
               ),
               const SizedBox(height: 12),
               PrimaryButton(
                 label: 'Join via Code',
                 onPressed: _showJoinBaseDialog,
                 filled: false,
               ),
             ],
           ),
         ),
       ),
      body: basesAsync.when(
        loading: () => const Center(child: MoonSpinner()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading bases: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(basesProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
                 data: (bases) => Column(
           children: [
             // Current Base Section
             if (selectedBase != null) ...[
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
                       'Current Base',
                       style: Theme.of(context).textTheme.titleSmall?.copyWith(
                         color: Theme.of(context).colorScheme.onPrimaryContainer,
                       ),
                     ),
                     const SizedBox(height: 8),
                     Row(
                       children: [
                         CircleAvatar(
                           backgroundColor: Theme.of(context).colorScheme.primary,
                           child: Text(
                             selectedBase.name[0].toUpperCase(),
                             style: const TextStyle(
                               color: Colors.white,
                               fontWeight: FontWeight.bold,
                             ),
                           ),
                         ),
                         const SizedBox(width: 12),
                         Expanded(
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Text(
                                 selectedBase.name,
                                 style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                   fontWeight: FontWeight.bold,
                                   color: Theme.of(context).colorScheme.onPrimaryContainer,
                                 ),
                               ),
                               if (selectedBase.description != null)
                                 Text(
                                   selectedBase.description!,
                                   style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                     color: Theme.of(context).colorScheme.onSurfaceVariant,
                                   ),
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

             // My Bases Section
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 16),
               child: Row(
                 children: [
                   Text(
                     'My Bases',
                     style: Theme.of(context).textTheme.titleLarge?.copyWith(
                       fontWeight: FontWeight.bold,
                     ),
                   ),
                   const Spacer(),
                   Text(
                     '${bases.length} base${bases.length == 1 ? '' : 's'}',
                     style: Theme.of(context).textTheme.bodySmall?.copyWith(
                       color: Theme.of(context).colorScheme.onSurfaceVariant,
                     ),
                   ),
                 ],
               ),
             ),

             const SizedBox(height: 16),

             // Bases List
             Expanded(
               child: bases.isEmpty
                   ? Center(
                       child: Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           Icon(
                             Icons.home_outlined,
                             size: 64,
                             color: Theme.of(context).colorScheme.outline,
                           ),
                           const SizedBox(height: 16),
                           Text(
                             'No bases yet',
                             style: Theme.of(context).textTheme.titleMedium?.copyWith(
                               color: Theme.of(context).colorScheme.onSurfaceVariant,
                             ),
                           ),
                           const SizedBox(height: 8),
                           Text(
                             'Create your first base to get started',
                             style: Theme.of(context).textTheme.bodySmall?.copyWith(
                               color: Theme.of(context).colorScheme.outline,
                             ),
                           ),
                         ],
                       ),
                     )
                   : ListView.builder(
                       padding: const EdgeInsets.symmetric(horizontal: 16),
                       itemCount: bases.length,
                       itemBuilder: (context, index) {
                         final base = bases[index];
                         final isSelected = selectedBase?.id == base.id;
                         
                         return Card(
                           margin: const EdgeInsets.only(bottom: 12),
                           child: ListTile(
                             leading: CircleAvatar(
                               backgroundColor: isSelected 
                                   ? Theme.of(context).colorScheme.primary
                                   : Theme.of(context).colorScheme.surfaceContainerHighest,
                               child: Text(
                                 base.name[0].toUpperCase(),
                                 style: TextStyle(
                                   color: isSelected 
                                       ? Colors.white
                                       : Theme.of(context).colorScheme.onSurface,
                                   fontWeight: FontWeight.bold,
                                 ),
                               ),
                             ),
                             title: Text(
                               base.name,
                               style: TextStyle(
                                 fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                               ),
                             ),
                             subtitle: base.description != null
                                 ? Text(base.description!)
                                 : null,
                             trailing: isSelected
                                 ? Icon(
                                     Icons.check_circle,
                                     color: Theme.of(context).colorScheme.primary,
                                   )
                                 : const Icon(Icons.chevron_right),
                             onTap: () => _switchBase(base),
                           ),
                         );
                       },
                     ),
             ),
           ],
         ),
      ),
    );
  }
}
