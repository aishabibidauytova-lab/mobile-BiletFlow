import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/async_list.dart';

/// Support (SRS 4.13): the user's cases, or — for staff — the cases they handle.
class SupportListScreen extends StatefulWidget {
  /// Platform admin view of cases escalated by organizers.
  final bool escalatedOnly;
  final bool embedded;
  const SupportListScreen({super.key, this.escalatedOnly = false, this.embedded = false});

  @override
  State<SupportListScreen> createState() => _SupportListScreenState();
}

(String, Color) supportStatusLabel(String s) => switch (s) {
      'OPEN' => (tr('support.status.OPEN'), Colors.blue.shade700),
      'IN_PROGRESS' => (tr('support.status.IN_PROGRESS'), Colors.orange.shade800),
      'WAITING_FOR_CUSTOMER' =>
        (tr('support.status.WAITING_FOR_CUSTOMER'), Colors.purple.shade600),
      'RESOLVED' => (tr('support.status.RESOLVED'), Colors.green.shade700),
      _ => (s, Colors.blueGrey),
    };

class _SupportListScreenState extends State<SupportListScreen> {
  final _list = GlobalKey<AsyncListState<SupportCase>>();
  String? _status;

  Future<List<SupportCase>> _load() => api.getSupportCases(
      status: _status, escalated: widget.escalatedOnly ? true : null);

  void _setStatus(String? s) {
    setState(() => _status = s);
    _list.currentState?.reload();
  }

  Future<void> _open(SupportCase c) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => SupportCaseScreen(caseId: c.id)));
    _list.currentState?.reload();
  }

  Future<void> _create() async {
    final created = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => const NewSupportCaseScreen()));
    if (created == true) _list.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: widget.embedded ? null : AppBar(
          title: Text(widget.escalatedOnly ? tr('support.escalatedTitle') : tr('support.title'))),
      floatingActionButton: widget.escalatedOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.add_comment_outlined),
              label: Text(tr('support.new')),
            ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final s in [null, ...supportStatuses])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(s == null ? tr('support.all') : supportStatusLabel(s).$1),
                      selected: _status == s,
                      onSelected: (_) => _setStatus(s),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AsyncList<SupportCase>(
              key: _list,
              load: _load,
              emptyText: tr('support.empty'),
              itemBuilder: (context, c) {
                final (label, color) = supportStatusLabel(c.status);
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    onTap: () => _open(c),
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.12),
                      child: Icon(Icons.forum_outlined, color: color),
                    ),
                    title: Text('№${c.id} · ${c.subject}',
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text([
                      c.eventTitle ?? tr('support.platform'),
                      tr('support.cat.${c.category}'),
                      if (c.updatedAt != null) formatDateTime(c.updatedAt!),
                    ].join(' • ')),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        StatusChip(label, color),
                        if (c.escalated)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Icon(Icons.priority_high, size: 16, color: cs.error),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens a new support case. When opened from an order or ticket, that context
/// is attached automatically (SRS 4.13).
class NewSupportCaseScreen extends StatefulWidget {
  final int? eventId;
  final int? orderId;
  final int? ticketId;

  /// Human-readable description of what the case is about, e.g. "Order №12".
  final String? context;

  const NewSupportCaseScreen(
      {super.key, this.eventId, this.orderId, this.ticketId, this.context});

  @override
  State<NewSupportCaseScreen> createState() => _NewSupportCaseScreenState();
}

class _NewSupportCaseScreenState extends State<NewSupportCaseScreen> {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  final _eventId = TextEditingController();
  final _orderId = TextEditingController();
  late String _type;
  String _category = 'TICKET_DELIVERY';
  bool _sending = false;
  String? _error;

  bool get _hasContext =>
      widget.eventId != null || widget.orderId != null || widget.ticketId != null;

  bool get _isOrganizer => AuthService.user?.role == 'ORGANIZER';

  @override
  void initState() {
    super.initState();
    // Attendee cases go to the event organizer; organizers may also write to
    // the platform. Without an event/order/ticket only the platform can help.
    _type = _hasContext || !_isOrganizer ? 'ATTENDEE' : 'PLATFORM';
    if (_type == 'PLATFORM') _category = 'ACCOUNT';
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    _eventId.dispose();
    _orderId.dispose();
    super.dispose();
  }

  int? _parse(TextEditingController c) => int.tryParse(c.text.trim());

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    final attendee = _type == 'ATTENDEE';
    final eventId = widget.eventId ?? _parse(_eventId);
    final orderId = widget.orderId ?? (attendee ? _parse(_orderId) : null);
    if (attendee && eventId == null && orderId == null && widget.ticketId == null) {
      setState(() => _error = tr('support.needContext'));
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final d = await api.openSupportCase(
        type: _type,
        category: _category,
        subject: _subject.text.trim(),
        message: _message.text.trim(),
        eventId: eventId,
        orderId: orderId,
        ticketId: attendee ? widget.ticketId : null,
      );
      if (!mounted) return;
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => SupportCaseScreen(caseId: d.supportCase.id)));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('support.new'))),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.context != null)
              Card(
                margin: const EdgeInsets.only(bottom: 14),
                child: ListTile(
                  leading: const Icon(Icons.link),
                  title: Text(tr('support.about')),
                  subtitle: Text(widget.context!),
                ),
              ),
            if (_isOrganizer) ...[
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'ATTENDEE', label: Text(tr('support.toOrganizer'))),
                  ButtonSegment(value: 'PLATFORM', label: Text(tr('support.toPlatform'))),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 14),
            ],
            DropdownButtonFormField<String>(
              initialValue: _category,
              isExpanded: true,
              decoration: InputDecoration(
                  labelText: tr('support.category'), border: const OutlineInputBorder()),
              items: [
                for (final c in supportCategories)
                  DropdownMenuItem(value: c, child: Text(tr('support.cat.$c'))),
              ],
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            if (!_hasContext) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _eventId,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: tr('support.eventId'),
                          border: const OutlineInputBorder()),
                    ),
                  ),
                  if (_type == 'ATTENDEE') ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _orderId,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: tr('support.orderId'),
                            border: const OutlineInputBorder()),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 14),
            TextFormField(
              controller: _subject,
              maxLength: 150,
              decoration: InputDecoration(
                  labelText: tr('support.subject'), border: const OutlineInputBorder()),
              validator: (v) => (v ?? '').trim().isEmpty ? tr('support.required') : null,
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _message,
              minLines: 4,
              maxLines: 8,
              decoration: InputDecoration(
                  labelText: tr('support.message'),
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder()),
              validator: (v) => (v ?? '').trim().isEmpty ? tr('support.required') : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: cs.error)),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
              label: Text(tr('support.send')),
            ),
          ],
        ),
      ),
    );
  }
}

/// One support case: the message thread, a reply box, and staff actions
/// (status, assignee, escalation) for the people who handle it.
class SupportCaseScreen extends StatefulWidget {
  final int caseId;
  const SupportCaseScreen({super.key, required this.caseId});

  @override
  State<SupportCaseScreen> createState() => _SupportCaseScreenState();
}

class _SupportCaseScreenState extends State<SupportCaseScreen> {
  SupportCaseDetail? _detail;
  String? _error;
  bool _busy = false;
  final _reply = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await api.getSupportCase(widget.caseId);
      if (mounted) setState(() => _detail = d);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  /// Returns true if the action succeeded.
  Future<bool> _run(Future<SupportCaseDetail> Function() action) async {
    setState(() => _busy = true);
    try {
      final d = await action();
      if (mounted) setState(() => _detail = d);
      return true;
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    if (await _run(() => api.replyToCase(widget.caseId, text)) && mounted) {
      _reply.clear();
    }
  }

  Future<void> _assign() async {
    final ctrl = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('support.assign')),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: InputDecoration(
              labelText: tr('support.assigneeEmail'), border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('no'))),
          FilledButton(
              onPressed: () => Navigator.pop(c, ctrl.text.trim()),
              child: Text(tr('support.assign'))),
        ],
      ),
    );
    ctrl.dispose();
    if (email != null && email.contains('@')) {
      await _run(() => api.assignCase(widget.caseId, email));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    if (d == null) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('support.title'))),
        body: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _load, child: Text(tr('retry'))),
                ]),
        ),
      );
    }

    final c = d.supportCase;
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final user = AuthService.user;
    final role = user?.role;
    final isRequester = user?.id == c.requesterId;
    final platformAdmin = role == 'PLATFORM_ADMIN';
    final handler = !isRequester &&
        (platformAdmin ||
            (c.type == 'ATTENDEE' && (role == 'ORGANIZER' || role == 'EVENT_ADMIN')));
    final canEscalate = handler && !c.escalated && (platformAdmin || role == 'ORGANIZER');
    final (label, color) = supportStatusLabel(c.status);

    return Scaffold(
      appBar: AppBar(
        title: Text('№${c.id}'),
        actions: [
          IconButton(tooltip: tr('retry'), onPressed: _load, icon: const Icon(Icons.refresh)),
          if (handler)
            PopupMenuButton<String>(
              enabled: !_busy,
              onSelected: (v) {
                if (v == 'assign') {
                  _assign();
                } else if (v == 'escalate') {
                  _run(() => api.escalateCase(c.id));
                } else {
                  _run(() => api.setCaseStatus(c.id, v));
                }
              },
              itemBuilder: (_) => [
                for (final s in supportStatuses)
                  if (s != c.status)
                    PopupMenuItem(
                        value: s,
                        child: Text(tr('support.setStatus', {'status': supportStatusLabel(s).$1}))),
                const PopupMenuDivider(),
                PopupMenuItem(value: 'assign', child: Text(tr('support.assign'))),
                if (canEscalate)
                  PopupMenuItem(value: 'escalate', child: Text(tr('support.escalate'))),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: cs.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.subject, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusChip(label, color),
                      Text(tr('support.cat.${c.category}'), style: t.bodySmall),
                      if (c.escalated)
                        StatusChip(tr('support.escalated'), cs.error),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      c.eventTitle ?? tr('support.platform'),
                      if (c.orderId != null) tr('orders.number', {'id': c.orderId}),
                      if (c.ticketId != null) tr('support.ticketN', {'id': c.ticketId}),
                    ].join(' • '),
                    style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  if (handler)
                    Text(
                      '${tr('support.requester')}: ${c.requesterEmail} • '
                      '${tr('support.assignee')}: ${c.assigneeEmail ?? tr('support.unassigned')}',
                      style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: d.messages.length,
                itemBuilder: (context, i) {
                  final m = d.messages[i];
                  // My messages on the right: staff replies when I handle the
                  // case, customer messages when I am the requester.
                  final mine = handler ? m.fromStaff : !m.fromStaff;
                  return Align(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.8),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        decoration: BoxDecoration(
                          color: mine ? cs.primaryContainer : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.fromStaff
                                  ? '${m.authorName} · ${tr('support.staff')}'
                                  : m.authorName,
                              style: t.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(m.body),
                            if (m.createdAt != null)
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Text(formatDateTime(m.createdAt!),
                                    style: t.labelSmall?.copyWith(color: cs.outline)),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
              child: c.status == 'RESOLVED' && !handler
                  ? Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(tr('support.resolvedHint'),
                          textAlign: TextAlign.center,
                          style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _reply,
                            minLines: 1,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: tr('support.replyHint'),
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton.filled(
                          tooltip: tr('support.send'),
                          onPressed: _busy ? null : _send,
                          icon: const Icon(Icons.send),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
