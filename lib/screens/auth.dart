import 'package:flutter/material.dart';

import '../cloud.dart';

class AuthScreen extends StatefulWidget {
  final CloudService cloud;
  const AuthScreen({super.key, required this.cloud});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _creating = false;
  bool _busy = false;
  bool _hide = true;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final err = _creating
        ? await widget.cloud.register(_email.text, _password.text)
        : await widget.cloud.signIn(_email.text, _password.text);
    if (!mounted) return;
    if (err == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  Future<void> _forgot() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Enter your email above first.');
      return;
    }
    final err = await widget.cloud.resetPassword(email);
    if (!mounted) return;
    setState(() {
      _error = err;
      _info = err == null ? 'Password reset email sent to $email.' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_creating ? 'Create account' : 'Sign in')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Back up your data and use it on more than one phone. '
              'Only you can see it.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || !v.contains('@') || !v.contains('.'))
                      ? 'Enter a valid email'
                      : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              obscureText: _hide,
              autofillHints: [
                _creating ? AutofillHints.newPassword : AutofillHints.password
              ],
              decoration: InputDecoration(
                labelText: 'Password',
                helperText: _creating ? 'At least 6 characters' : null,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _hide ? 'Show password' : 'Hide password',
                  icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _hide = !_hide),
                ),
              ),
              validator: (v) =>
                  (v == null || v.length < 6) ? 'At least 6 characters' : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
            if (_info != null) ...[
              const SizedBox(height: 12),
              Text(_info!),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_creating ? 'Create account' : 'Sign in'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () => setState(() {
                _creating = !_creating;
                _error = null;
                _info = null;
              }),
              child: Text(_creating
                  ? 'I already have an account'
                  : 'New here? Create an account'),
            ),
            if (!_creating)
              TextButton(
                onPressed: _busy ? null : _forgot,
                child: const Text('Forgot password?'),
              ),
          ],
        ),
      ),
    );
  }
}
