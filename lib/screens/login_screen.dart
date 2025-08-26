import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '/services/session_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _c = TextEditingController();
  String? _error;
  bool _submitting = false;

  bool get _valid {
    final t = _c.text.trim();
    final re = RegExp(r'^[\w\- ]{2,24}$'); // letters/numbers/_-/space
    return re.hasMatch(t);
  }

  Future<void> _submit() async {
    if (!_valid || _submitting) return;
    setState(() => _submitting = true);
    try {
      await ref.read(sessionProvider.notifier).signIn(_c.text);
      if (mounted) context.go('/home');
    } catch (_) {
      setState(() => _error = 'Could not create profile. Try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final disabled = _submitting || session.isLoading || !_valid;

    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("Pick a nickname (no email/phone needed)"),
            const SizedBox(height: 8),
            TextField(
              controller: _c,
              decoration: InputDecoration(
                labelText: 'Nickname',
                errorText: _error,
                helperText: '2–24 chars. Letters, numbers, _ or -',
              ),
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: disabled ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 18, width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
