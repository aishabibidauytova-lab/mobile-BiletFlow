import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/async_list.dart';
import '../widgets/date_time_field.dart';
import '../widgets/event_poster.dart';
import 'event_form_screen.dart';
import 'organizer_events_screen.dart' show eventStatusColor;
import 'scanner_screen.dart';

/// Organizer's control panel for one event: poster, status actions,
/// ticket types and check-in staff.
class ManageEventScreen extends StatefulWidget {
  final EventInfo event;

  /// Optionally scroll to a section after loading: 'tickets' or 'staff'.
  final String? section;
  const ManageEventScreen({super.key, required this.event, this.section});

  @override
  State<ManageEventScreen> createState() => _ManageEventScreenState();
}

class _ManageEventScreenState extends State<ManageEventScreen> {
  late EventInfo _event = widget.event;
  List<TicketType> _types = [];
  List<StaffMember> _staff = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  final _ticketsKey = GlobalKey();
  final _staffKey = GlobalKey();
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final results = await Future.wait([
        api.getEvent(_event.id),
        api.getAllTicketTypes(_event.id),
        api.getStaff(_event.id),
      ]);
      if (!mounted) return;
      setState(() {
        _event = results[0] as EventInfo;
        _types = results[1] as List<TicketType>;
        _staff = results[2] as List<StaffMember>;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
      _scrollToSection();
    }
  }

  void _scrollToSection() {
    if (_scrolled || widget.section == null) return;
    _scrolled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = (widget.section == 'staff' ? _staffKey : _ticketsKey).currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300));
      }
    });
  }

  void _toast(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Runs [action], shows API errors as a toast, and keeps the busy flag.
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

  // --- Poster ---------------------------------------------------------------

  Future<void> _pickPoster() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final name = file.name.toLowerCase();
    final mime = name.endsWith('.png')
        ? 'image/png'
        : name.endsWith('.webp')
            ? 'image/webp'
            : 'image/jpeg';
    await _run(() async {
      final bytes = await file.readAsBytes();
      final updated = await api.uploadPoster(_event.id, bytes, file.name, mime);
      setState(() => _event = updated);
      _toast(tr('manage.posterUpdated'));
    });
  }

  Future<void> _removePoster() => _run(() async {
        await api.deletePoster(_event.id);
        await _reload();
      });

  // --- Event actions ----------------------------------------------------------

  Future<void> _edit() async {
    final saved = await Navigator.push<EventInfo>(
      context,
      MaterialPageRoute(builder: (_) => EventFormScreen(event: _event)),
    );
    if (saved != null) {
      setState(() => _event = saved);
      _reload();
    }
  }

  Future<void> _togglePublish() => _run(() async {
        final updated = _event.status == 'PUBLISHED'
            ? await api.unpublishEvent(_event.id)
            : await api.publishEvent(_event.id);
        setState(() => _event = updated);
      });

  Future<void> _duplicate() => _run(() async {
        final copy = await api.duplicateEvent(_event.id);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ManageEventScreen(event: copy)),
        );
      });

  Future<void> _cancelEvent() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('manage.cancelTitle')),
        content: Text(tr('manage.cancelBody')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('no'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error),
            onPressed: () => Navigator.pop(c, true),
            child: Text(tr('manage.cancelEvent')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      final updated = await api.cancelEvent(_event.id);
      setState(() => _event = updated);
      await _reload();
    });
  }

  // --- Ticket types -----------------------------------------------------------

  Future<void> _editTicketType([TicketType? type]) async {
    final body = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _TicketTypeDialog(type: type),
    );
    if (body == null) return;
    await _run(() async {
      if (type == null) {
        await api.createTicketType(_event.id, body);
      } else {
        await api.updateTicketType(type.id, body);
      }
      await _reload();
    });
  }

  Future<void> _toggleHidden(TicketType t) => _run(() async {
        if (t.hidden) {
          await api.unhideTicketType(t.id);
        } else {
          await api.hideTicketType(t.id);
        }
        await _reload();
      });

  // --- Staff ----------------------------------------------------------------------

  Future<void> _addStaff() async {
    final ctrl = TextEditingController();
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('staff.add')),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: ctrl,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                    labelText: tr('staff.email'), border: const OutlineInputBorder()),
                validator: (v) =>
                    (v ?? '').contains('@') ? null : tr('login.emailInvalid'),
              ),
              const SizedBox(height: 10),
              Text(tr('staff.hint'), style: Theme.of(c).textTheme.bodySmall),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('cancel'))),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(c, true);
            },
            child: Text(tr('add')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      await api.assignStaff(_event.id, ctrl.text.trim());
      await _reload();
    });
  }

  Future<void> _removeStaff(StaffMember s) => _run(() async {
        await api.removeStaff(_event.id, s.userId);
        await _reload();
      });

  // --- UI -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final e = _event;
    final cancelled = e.isCancelled;
    final border = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: cs.outlineVariant),
    );
    Widget heading(String text, {Widget? action, Key? anchor}) => Padding(
          key: anchor,
          padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(text,
                    style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              ),
              ?action,
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(tr('manage.title'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(_error!, style: TextStyle(color: cs.error)),
                        ),
                      if (_busy) const LinearProgressIndicator(),
                      // Poster.
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: AspectRatio(
                          aspectRatio: 16 / 7,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              EventPoster(event: e),
                              Positioned(
                                left: 12,
                                top: 12,
                                child: Wrap(spacing: 6, children: [
                                  _Pill(tr('ev.${e.status}'), eventStatusColor(e.status)),
                                  _Pill(tr('vis.${e.visibility}'), Colors.blueGrey),
                                ]),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _busy || cancelled ? null : _pickPoster,
                            icon: const Icon(Icons.image_outlined),
                            label: Text((e.posterUrl ?? '').isEmpty
                                ? tr('manage.upload')
                                : tr('manage.replace')),
                          ),
                          if ((e.posterUrl ?? '').isNotEmpty)
                            TextButton.icon(
                              onPressed: _busy || cancelled ? null : _removePoster,
                              icon: const Icon(Icons.delete_outline),
                              label: Text(tr('manage.removePoster')),
                            ),
                          Text(tr('manage.posterHint'),
                              style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(e.title,
                          style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(e.subtitle,
                          style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 14),
                      // Actions.
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: _busy || cancelled ? null : _edit,
                            icon: const Icon(Icons.edit_outlined),
                            label: Text(tr('edit')),
                          ),
                          if (!cancelled)
                            FilledButton.icon(
                              onPressed: _busy ? null : _togglePublish,
                              icon: Icon(e.status == 'PUBLISHED'
                                  ? Icons.visibility_off_outlined
                                  : Icons.publish),
                              label: Text(e.status == 'PUBLISHED'
                                  ? tr('manage.unpublish')
                                  : tr('manage.publish')),
                            ),
                          FilledButton.tonalIcon(
                            onPressed: _busy ? null : _duplicate,
                            icon: const Icon(Icons.copy_all_outlined),
                            label: Text(tr('manage.duplicate')),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _busy || cancelled
                                ? null
                                : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => ScannerScreen(event: e)),
                                    ),
                            icon: const Icon(Icons.qr_code_scanner),
                            label: Text(tr('manage.checkin')),
                          ),
                          if (!cancelled)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(foregroundColor: cs.error),
                              onPressed: _busy ? null : _cancelEvent,
                              icon: const Icon(Icons.cancel_outlined),
                              label: Text(tr('manage.cancelEvent')),
                            ),
                        ],
                      ),
                      // Ticket types.
                      heading(
                        tr('manage.ticketTypes'),
                        anchor: _ticketsKey,
                        action: FilledButton.tonalIcon(
                          onPressed: _busy || cancelled ? null : () => _editTicketType(),
                          icon: const Icon(Icons.add),
                          label: Text(tr('add')),
                        ),
                      ),
                      if (_types.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(tr('manage.noTicketTypes')),
                        ),
                      for (final tt in _types)
                        Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: border,
                          child: ListTile(
                            contentPadding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                            title: Row(children: [
                              Flexible(
                                child: Text(tt.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w700)),
                              ),
                              if (tt.hidden) ...[
                                const SizedBox(width: 8),
                                StatusChip(tr('tt.hidden'), Colors.blueGrey),
                              ],
                            ]),
                            subtitle: Text(
                              '${formatPrice(tt.price)} • ${tr('tt.sold', {
                                    'sold': tt.sold,
                                    'total': tt.quantity
                                  })}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: tr('edit'),
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: _busy || cancelled ? null : () => _editTicketType(tt),
                                ),
                                IconButton(
                                  tooltip: tt.hidden ? tr('tt.unhide') : tr('tt.hide'),
                                  icon: Icon(tt.hidden
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined),
                                  onPressed: _busy || cancelled ? null : () => _toggleHidden(tt),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Staff.
                      heading(
                        tr('manage.staff'),
                        anchor: _staffKey,
                        action: FilledButton.tonalIcon(
                          onPressed: _busy ? null : _addStaff,
                          icon: const Icon(Icons.person_add_alt_1_outlined),
                          label: Text(tr('add')),
                        ),
                      ),
                      if (_staff.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(tr('manage.noStaff')),
                        ),
                      for (final s in _staff)
                        Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: border,
                          child: ListTile(
                            leading: const Icon(Icons.badge_outlined),
                            title: Text(s.email),
                            subtitle: s.assignedAt == null
                                ? null
                                : Text(formatDateTime(s.assignedAt!)),
                            trailing: IconButton(
                              tooltip: tr('staff.remove'),
                              icon: const Icon(Icons.person_remove_outlined),
                              onPressed: _busy ? null : () => _removeStaff(s),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
      );
}

/// Create / edit ticket type. Pops with the request body.
class _TicketTypeDialog extends StatefulWidget {
  final TicketType? type;
  const _TicketTypeDialog({this.type});

  @override
  State<_TicketTypeDialog> createState() => _TicketTypeDialogState();
}

class _TicketTypeDialogState extends State<_TicketTypeDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.type?.name);
  late final _description = TextEditingController(text: widget.type?.description);
  late final _price =
      TextEditingController(text: widget.type == null ? '0' : '${widget.type!.price}');
  late final _quantity =
      TextEditingController(text: widget.type == null ? '' : '${widget.type!.quantity}');
  late final _maxPerOrder =
      TextEditingController(text: widget.type == null ? '' : '${widget.type!.maxPerOrder}');
  late DateTime? _salesStart = widget.type?.salesStart;
  late DateTime? _salesEnd = widget.type?.salesEnd;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _quantity.dispose();
    _maxPerOrder.dispose();
    super.dispose();
  }

  String? _req(String? v) => (v ?? '').trim().isEmpty ? tr('required') : null;

  String? _int(String? v, {bool optional = false}) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return optional ? null : tr('required');
    final n = int.tryParse(s);
    return n == null || n <= 0 ? tr('enterNumber') : null;
  }

  String? _money(String? v) {
    final n = num.tryParse((v ?? '').trim().replaceAll(',', '.'));
    return n == null || n < 0 ? tr('enterNumber') : null;
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final max = int.tryParse(_maxPerOrder.text.trim());
    Navigator.pop<Map<String, dynamic>>(context, {
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'price': num.parse(_price.text.trim().replaceAll(',', '.')),
      'quantity': int.parse(_quantity.text.trim()),
      'maxPerOrder': ?max,
      if (_salesStart != null) 'salesStart': isoLocal(_salesStart!),
      if (_salesEnd != null) 'salesEnd': isoLocal(_salesEnd!),
    });
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String l) =>
        InputDecoration(labelText: l, border: const OutlineInputBorder());
    const gap = SizedBox(height: 12);
    return AlertDialog(
      title: Text(widget.type == null ? tr('tt.new') : tr('tt.edit')),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                    controller: _name,
                    autofocus: true,
                    decoration: deco(tr('tt.name')),
                    validator: _req),
                gap,
                TextFormField(
                    controller: _description,
                    decoration: deco(tr('form.description')),
                    maxLines: 2),
                gap,
                TextFormField(
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: deco(tr('tt.price')),
                  validator: _money,
                ),
                gap,
                TextFormField(
                  controller: _quantity,
                  keyboardType: TextInputType.number,
                  decoration: deco(tr('tt.quantity')),
                  validator: _int,
                ),
                gap,
                TextFormField(
                  controller: _maxPerOrder,
                  keyboardType: TextInputType.number,
                  decoration: deco(tr('tt.maxPerOrder')),
                  validator: (v) => _int(v, optional: true),
                ),
                gap,
                DateTimeField(
                    label: tr('tt.salesStart'),
                    value: _salesStart,
                    onChanged: (v) => setState(() => _salesStart = v)),
                gap,
                DateTimeField(
                    label: tr('tt.salesEnd'),
                    value: _salesEnd,
                    onChanged: (v) => setState(() => _salesEnd = v)),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('cancel'))),
        FilledButton(onPressed: _submit, child: Text(tr('save'))),
      ],
    );
  }
}
