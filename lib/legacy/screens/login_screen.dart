import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moonbase_skeleton/core/failure.dart';
import 'package:moonbase_skeleton/core/presentation/failure_presenter.dart';
import 'package:moonbase_skeleton/core/presentation/failure_snackbar.dart';
import 'package:moonbase_skeleton/features/auth/presentation/controllers/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  static const fallbackCopy = 'Could not sign in. Try again.';

  /// B-e login half: sign-in may block on the create-or-return profile write
  /// (unbounded, trigger #12) or fail the 20s guard. Say so plainly instead
  /// of the generic network copy.
  static const kLoginNetworkCopy =
      'MoonBase needs a connection to finish setting up your account. '
      'Check Wi-Fi or mobile data and try again.';

  /// Copy for a sign-in failure. [error] is the raw object from the auth
  /// state (normally a `Failure`); null means the session ended up neither
  /// signed in nor errored.
  static String signInCopy(Object? error) {
    if (error == null) return fallbackCopy;
    if (error is NetworkFailure || error is NetworkTimeoutFailure) {
      return kLoginNetworkCopy;
    }
    return userMessage(error);
  }

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

  Object? _errorFromAuthState() {
    final current = ref.read(authControllerProvider).current;
    return current.whenOrNull(error: (e, _) => e);
  }

  /// Inline (persistent, up to 3 lines) **and** snackbar, same copy. Fields
  /// are never cleared on failure — the form must survive the attempt.
  void _showFailure(Object? error) {
    final copy = LoginScreen.signInCopy(error);
    setState(() => _error = copy);
    showFailureSnackBar(context, error, message: copy);
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
        _showFailure(_errorFromAuthState());
      }
    } catch (e) {
      if (mounted) _showFailure(e);
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Owner sign-in',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                  'Use the email and password for your MoonBase account.'),
              const SizedBox(height: 16),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(
                  labelText: 'Email',
                  errorText: _error,
                  // Default is 1 line — long failure copy was being clipped.
                  errorMaxLines: 3,
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
      ),
    );
  }
}
