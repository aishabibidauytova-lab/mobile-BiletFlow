import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/async_list.dart';
import 'login_screen.dart';

/// Account page: email/password, language-independent info, organizer profile,
/// "become an organizer" and account deletion.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  OrganizerProfile? _profile;
  bool _busy = false;

  AppUser get _user => AuthService.user!;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (_user.role != 'ORGANIZER') return;
    try {
      final p = await api.getOrganizerProfile();
      if (mounted) setState(() => _profile = p);
    } catch (_) {
      // Profile card is optional.
    }
  }

  void _toast(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeCredentials({required bool email}) async {
    final ctrl = TextEditingController();
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(email ? tr('profile.changeEmail') : tr('profile.changePassword')),
        content: Form(
          key: form,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            obscureText: !email,
            keyboardType: email ? TextInputType.emailAddress : TextInputType.text,
            decoration: InputDecoration(
              labelText: email ? tr('profile.newEmail') : tr('profile.newPassword'),
              border: const OutlineInputBorder(),
            ),
            validator: (v) {
              final t = (v ?? '').trim();
              if (email) return t.contains('@') ? null : tr('login.emailInvalid');
              return t.length >= 6 ? null : tr('profile.passwordShort');
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('cancel'))),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(c, true);
            },
            child: Text(tr('save')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final value = ctrl.text.trim();
    await _run(() async {
      final updated = await api.updateCredentials(
        email: email ? value : null,
        password: email ? null : value,
      );
      AuthService.user = updated;
      _toast(tr('saved'));
    });
  }

  Future<void> _becomeOrganizer() async {
    final ctrl = TextEditingController();
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('profile.becomeOrganizer')),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr('profile.becomeBody')),
              const SizedBox(height: 12),
              TextFormField(
                controller: ctrl,
                autofocus: true,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: tr('profile.contact'),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? tr('required') : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('cancel'))),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(c, true);
            },
            child: Text(tr('profile.becomeOrganizer')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      final token = await api.becomeOrganizer(ctrl.text.trim());
      await AuthService.adoptToken(token);
      _toast(tr('profile.becameOrganizer'));
      await _loadProfile();
    });
  }

  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('profile.deleteTitle')),
        content: Text(tr('profile.deleteBody')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('no'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error),
            onPressed: () => Navigator.pop(c, true),
            child: Text(tr('delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      await api.deleteMyAccount();
      await AuthService.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final u = _user;
    final border = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: cs.outlineVariant),
    );

    return Scaffold(
      appBar: AppBar(title: Text(tr('profile.title'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              // Identity card.
              Card(
                margin: EdgeInsets.zero,
                shape: border,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: cs.primaryContainer,
                        child: Text(
                          u.email.isEmpty ? '?' : u.email[0].toUpperCase(),
                          style: t.headlineSmall?.copyWith(
                              color: cs.onPrimaryContainer, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u.email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            StatusChip(tr('role.${u.role}'), cs.primary),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                margin: EdgeInsets.zero,
                shape: border,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.alternate_email),
                      title: Text(tr('profile.changeEmail')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _busy ? null : () => _changeCredentials(email: true),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: Text(tr('profile.changePassword')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _busy ? null : () => _changeCredentials(email: false),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (u.role == 'ATTENDEE')
                Card(
                  margin: EdgeInsets.zero,
                  shape: border,
                  color: cs.primaryContainer.withValues(alpha: 0.5),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.campaign_outlined, color: cs.primary),
                          const SizedBox(width: 10),
                          Text(tr('profile.becomeOrganizer'),
                              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                        ]),
                        const SizedBox(height: 8),
                        Text(tr('profile.becomeBody')),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _busy ? null : _becomeOrganizer,
                          child: Text(tr('profile.becomeOrganizer')),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_profile != null)
                Card(
                  margin: EdgeInsets.zero,
                  shape: border,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('profile.organizerSection'),
                            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        Text(tr('profile.contact'),
                            style: t.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                        Text(_profile!.contactInformation),
                        const SizedBox(height: 10),
                        Text(tr('profile.verification'),
                            style: t.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: StatusChip(
                            _verification(_profile!.verificationStatus),
                            _profile!.verificationStatus == 'VERIFIED'
                                ? Colors.green.shade700
                                : Colors.blueGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: cs.error),
                onPressed: _busy ? null : _deleteAccount,
                icon: const Icon(Icons.delete_outline),
                label: Text(tr('profile.delete')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _verification(String s) {
    final v = tr('verif.$s');
    return v == 'verif.$s' ? s : v;
  }
}
