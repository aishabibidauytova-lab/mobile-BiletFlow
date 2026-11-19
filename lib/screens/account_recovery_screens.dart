import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../services/api_service.dart';

/// Forgot password (SRS 4.1): request a reset email, then enter the token from
/// the email together with a new password.
class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _email = TextEditingController(text: widget.initialEmail);
  final _token = TextEditingController();
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _sent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _token.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _request() {
    if (!_email.text.contains('@')) {
      setState(() => _error = tr('login.emailInvalid'));
      return;
    }
    _run(() async {
      await api.forgotPassword(_email.text.trim());
      if (mounted) setState(() => _sent = true);
    });
  }

  void _reset() {
    if (!_form.currentState!.validate()) return;
    _run(() async {
      await api.resetPassword(_token.text.trim(), _password.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('recover.done'))));
      Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('recover.title'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(tr('recover.step1'), style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(tr('recover.step1Hint'), style: t.bodySmall),
                const SizedBox(height: 12),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                      labelText: 'Email', border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                FilledButton.tonal(
                  onPressed: _busy ? null : _request,
                  child: Text(_sent ? tr('recover.resend') : tr('recover.send')),
                ),
                if (_sent) ...[
                  const SizedBox(height: 8),
                  Text(tr('recover.sent'), style: TextStyle(color: Colors.green.shade700)),
                ],
                const Divider(height: 36),
                Text(tr('recover.step2'), style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(tr('recover.step2Hint'), style: t.bodySmall),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _token,
                  decoration: InputDecoration(
                      labelText: tr('recover.token'), border: const OutlineInputBorder()),
                  validator: (v) => (v ?? '').trim().isEmpty ? tr('support.required') : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: InputDecoration(
                      labelText: tr('profile.newPassword'),
                      border: const OutlineInputBorder()),
                  validator: (v) =>
                      (v ?? '').length >= 6 ? null : tr('profile.passwordShort'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: TextStyle(color: cs.error)),
                ],
                const SizedBox(height: 14),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: _busy ? null : _reset,
                  child: Text(tr('recover.reset')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Email verification (SRS 4.1): enter the token from the verification email,
/// or ask for a new email.
class VerifyEmailScreen extends StatefulWidget {
  final String initialEmail;
  const VerifyEmailScreen({super.key, this.initialEmail = ''});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  late final _email = TextEditingController(text: widget.initialEmail);
  final _token = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await action();
      if (mounted) setState(() => _info = done);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('verify.title'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(tr('verify.hint'), style: t.bodyMedium),
              const SizedBox(height: 14),
              TextField(
                controller: _token,
                decoration: InputDecoration(
                    labelText: tr('recover.token'), border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: _busy
                    ? null
                    : () {
                        if (_token.text.trim().isEmpty) {
                          setState(() => _error = tr('support.required'));
                          return;
                        }
                        _run(() => api.verifyEmail(_token.text.trim()), tr('verify.done'));
                      },
                child: Text(tr('verify.confirm')),
              ),
              const Divider(height: 36),
              Text(tr('verify.noEmail'), style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Email', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () {
                        if (!_email.text.contains('@')) {
                          setState(() => _error = tr('login.emailInvalid'));
                          return;
                        }
                        _run(() => api.resendVerification(_email.text.trim()),
                            tr('verify.resent'));
                      },
                child: Text(tr('verify.resend')),
              ),
              if (_info != null) ...[
                const SizedBox(height: 12),
                Text(_info!, style: TextStyle(color: Colors.green.shade700)),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: cs.error)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
