import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/features/auth/presentation/controllers/auth_controller.dart';
import 'package:moonbase_skeleton/legacy/widgets/primary_button.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String _messageFromAuthState() {
    final current = ref.read(authControllerProvider).current;
    return current.when(
      data: (_) => 'Could not create account. Try again.',
      loading: () => 'Could not create account. Try again.',
      error: (e, _) =>
          e is Failure ? e.message : 'Could not create account. Try again.',
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).signUp(
            _email.text.trim(),
            _password.text,
          );
      if (!mounted) return;
      final user = ref.read(authControllerProvider).current.valueOrNull;
      if (user != null) {
        context.go('/home');
      } else {
        setState(() => _error = _messageFromAuthState());
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not create account. Try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Create your owner account',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Base leaders sign up with email and password. '
                'This account anchors your bases.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(
                  labelText: 'Email',
                  errorText: _error,
                ),
                onChanged: (_) => setState(() => _error = null),
                validator: (v) =>
                    (v == null || v.trim().isEmpty || !v.contains('@'))
                        ? 'Enter email'
                        : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(
                  labelText: 'Password',
                  helperText: 'At least 6 characters',
                ),
                validator: (v) =>
                    (v == null || v.length < 6) ? 'Min 6 chars' : null,
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: _submitting ? 'Creating…' : 'Create account',
                onPressed: _submit,
              ),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Already have an account? Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
