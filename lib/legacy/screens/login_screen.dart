import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/features/auth/presentation/controllers/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _submitting = false;

  bool get _valid {
    final email = _email.text.trim();
    return email.contains('@') && _password.text.length >= 6;
  }

  String _messageFromAuthState() {
    final current = ref.read(authControllerProvider).current;
    return current.when(
      data: (_) => 'Could not sign in. Try again.',
      loading: () => 'Could not sign in. Try again.',
      error: (e, _) => e is Failure ? e.message : 'Could not sign in. Try again.',
    );
  }

  Future<void> _submit() async {
    if (!_valid || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).signIn(
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
        setState(() => _error = 'Could not sign in. Try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = _submitting || !_valid;

    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Owner sign-in',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text('Use the email and password for your MoonBase account.'),
            const SizedBox(height: 16),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(
                labelText: 'Email',
                errorText: _error,
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(
                labelText: 'Password',
                helperText: 'At least 6 characters',
              ),
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: disabled ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sign in'),
            ),
            TextButton(
              onPressed: () => context.go('/signup'),
              child: const Text('Create an account'),
            ),
          ],
        ),
      ),
    );
  }
}
