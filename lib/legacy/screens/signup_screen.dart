import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moonbase_skeleton/core/presentation/failure_presenter.dart';
import 'package:moonbase_skeleton/core/presentation/failure_snackbar.dart';
import 'package:moonbase_skeleton/core/validators.dart';
import 'package:moonbase_skeleton/features/auth/presentation/controllers/auth_controller.dart';
import 'package:moonbase_skeleton/legacy/widgets/primary_button.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nickname = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _nickname.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  static const fallbackCopy = 'Could not create your account. Try again.';

  void _showFailure(Object? error) {
    final copy = error == null ? fallbackCopy : userMessage(error);
    setState(() => _error = copy);
    showFailureSnackBar(context, error, message: copy);
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
            nickname: _nickname.text.trim(),
          );
      if (!mounted) return;
      final user = ref.read(authControllerProvider).current.valueOrNull;
      if (user != null) {
        context.go('/home');
      } else {
        _showFailure(
          ref.read(authControllerProvider).current.whenOrNull(
                error: (e, _) => e,
              ),
        );
      }
    } catch (e) {
      if (mounted) _showFailure(e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: SingleChildScrollView(
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
                  'Pick a nickname for chat, then sign up with email and password. '
                  'This account anchors your bases.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nickname,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.nickname],
                  decoration: const InputDecoration(
                    labelText: 'Nickname',
                    helperText: 'Shown in chat (1–24 characters)',
                  ),
                  onChanged: (_) => setState(() => _error = null),
                  validator: (v) {
                    if (v == null || !isValidNickname(v)) {
                      return 'Nickname needs 1–24 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
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
                          ? 'Enter a valid email address.'
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
                      (v == null || v.length < 6)
                          ? 'Use at least 6 characters.'
                          : null,
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
      ),
    );
  }
}
