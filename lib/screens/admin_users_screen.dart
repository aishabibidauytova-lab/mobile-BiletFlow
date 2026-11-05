import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

/// Platform admin page (mirrors the website): all accounts, inline editing of
/// email / password, and delete. Roles are not editable — the API has no
/// endpoint for that.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  late Future<List<UserAccount>> _future = api.getUsers();
  final _search = TextEditingController();
  String _query = '';
  int? _openId; // the user whose edit form is expanded

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _future = api.getUsers());
    await _future.then((_) {}, onError: (_) {});
  }

  void _toast(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _delete(UserAccount u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('admin.deleteTitle')),
        content: Text(tr('admin.deleteBody', {'email': u.email})),
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
    try {
      await api.deleteUser(u.id);
      if (_openId == u.id) _openId = null;
      await _reload();
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: FutureBuilder<List<UserAccount>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              final err = snap.error;
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(err is ApiException ? err.message : tr('err.load')),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: _reload, child: Text(tr('retry'))),
                  ],
                ),
              );
            }
            final q = _query.trim().toLowerCase();
            final users = [
              for (final u in snap.data ?? const <UserAccount>[])
                if (q.isEmpty || u.email.toLowerCase().contains(q)) u,
            ];
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Text(tr('admin.title'),
                      style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(tr('admin.subtitle'),
                      style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 14),
                  SearchBar(
                    controller: _search,
                    hintText: tr('admin.search'),
                    leading: const Icon(Icons.search),
                    elevation: const WidgetStatePropertyAll(0),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: 14),
                  if (users.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: Text(tr('admin.empty'))),
                    ),
                  for (final u in users)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _UserCard(
                        key: ValueKey('${u.id}-${u.email}'),
                        user: u,
                        isSelf: u.id == AuthService.user?.id,
                        open: _openId == u.id,
                        onToggle: () =>
                            setState(() => _openId = _openId == u.id ? null : u.id),
                        onDelete: () => _delete(u),
                        onSaved: () async {
                          setState(() => _openId = null);
                          await _reload();
                        },
                        onError: _toast,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _UserCard extends StatefulWidget {
  final UserAccount user;
  final bool isSelf;
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final Future<void> Function() onSaved;
  final void Function(String) onError;

  const _UserCard({
    super.key,
    required this.user,
    required this.isSelf,
    required this.open,
    required this.onToggle,
    required this.onDelete,
    required this.onSaved,
    required this.onError,
  });

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.user.email);
  final _password = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final email = _email.text.trim();
    final password = _password.text;
    final emailChanged = email != widget.user.email;
    if (!emailChanged && password.isEmpty) {
      widget.onError(tr('admin.nothingChanged'));
      return;
    }
    setState(() => _saving = true);
    try {
      await api.updateUser(
        widget.user.id,
        email: emailChanged ? email : null,
        password: password.isEmpty ? null : password,
      );
      _password.clear();
      await widget.onSaved();
    } on ApiException catch (e) {
      widget.onError(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final u = widget.user;

    return Material(
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                        tr('admin.idRole', {'id': u.id, 'role': tr('role.${u.role}')}),
                        style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: widget.onToggle,
                  child: Text(widget.open ? tr('admin.close') : tr('admin.edit')),
                ),
                if (!widget.isSelf) ...[
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(foregroundColor: cs.error),
                    onPressed: widget.onDelete,
                    child: Text(tr('delete')),
                  ),
                ],
              ],
            ),
            if (widget.open) ...[
              const Divider(height: 28),
              Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v ?? '').contains('@') ? null : tr('login.emailInvalid'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: tr('admin.newPassword'),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => (v ?? '').isEmpty || v!.length >= 6
                          ? null
                          : tr('profile.passwordShort'),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(tr('admin.saveChanges')),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
