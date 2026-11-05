import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/async_list.dart';
import 'scanner_screen.dart';

/// Check-in page for staff (mirrors the website): choose an assigned event,
/// see live stats, verify a ticket by typing its code, search attendees and
/// check them in manually — or open the camera scanner.
class EventSelectionScreen extends StatefulWidget {
  const EventSelectionScreen({super.key});

  @override
  State<EventSelectionScreen> createState() => _EventSelectionScreenState();
}

class _EventSelectionScreenState extends State<EventSelectionScreen> {
  List<EventInfo> _events = [];
  EventInfo? _event;
  bool _loading = true;
  String? _error;

  EventStats _stats = const EventStats(0, 0);
  List<Ticket> _attendees = [];
  bool _searching = false;
  final Set<int> _working = {};

  final _code = TextEditingController();
  final _query = TextEditingController();
  bool _verifying = false;
  ScanResult? _result;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _code.dispose();
    _query.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loadEvents() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await api.getAssignedEvents();
      if (!mounted) return;
      setState(() {
        _events = list;
        _event = list.isEmpty ? null : list.first;
      });
      if (_event != null) await _refresh();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Reloads stats and the attendee list for the selected event.
  Future<void> _refresh() async {
    final e = _event;
    if (e == null) return;
    setState(() => _searching = true);
    try {
      final results = await Future.wait([
        api.getStats(e.id),
        api.searchAttendees(e.id, _query.text),
      ]);
      if (!mounted || _event?.id != e.id) return;
      setState(() {
        _stats = results[0] as EventStats;
        _attendees = results[1] as List<Ticket>;
      });
    } on ApiException catch (err) {
      _toast(err.message);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectEvent(EventInfo e) {
    setState(() {
      _event = e;
      _result = null;
      _attendees = [];
      _stats = const EventStats(0, 0);
    });
    _refresh();
  }

  Future<void> _verify() async {
    final e = _event;
    final code = _code.text.trim();
    if (e == null || code.isEmpty) return;
    setState(() => _verifying = true);
    ScanResult result;
    if (QrPayload.looksLikeLink(code)) {
      // Campaign QR codes (links) never grant entry.
      result = ScanResult(ScanOutcome.notTicket, message: tr('scan.promoQr'));
    } else {
      try {
        result = await api.checkIn(e.id, code);
      } on ApiException catch (err) {
        result = ScanResult(ScanOutcome.error, message: err.message);
      }
    }
    if (!mounted) return;
    setState(() {
      _result = result;
      _verifying = false;
    });
    if (result.outcome == ScanOutcome.success) {
      _code.clear();
      _refresh();
    }
  }

  Future<void> _undo(Ticket t) async {
    final e = _event;
    if (e == null) return;
    setState(() => _working.add(t.id));
    try {
      await api.undoCheckIn(e.id, t.id);
      _toast(tr('scan.undone'));
      if (_result?.ticket?.id == t.id) _result = null;
      await _refresh();
    } on ApiException catch (err) {
      _toast(err.message);
    } finally {
      if (mounted) setState(() => _working.remove(t.id));
    }
  }

  Future<void> _checkInAttendee(Ticket t) async {
    final e = _event;
    if (e == null) return;
    setState(() => _working.add(t.id));
    try {
      final r = await api.checkIn(e.id, t.code);
      switch (r.outcome) {
        case ScanOutcome.success:
          _toast(tr('att.checkedIn', {'email': t.attendeeEmail}));
        case ScanOutcome.alreadyUsed:
          _toast(tr('att.alreadyUsed'));
        case ScanOutcome.cancelled:
          _toast(tr('att.cancelled'));
        default:
          _toast(r.message ?? tr('att.failed'));
      }
      await _refresh();
    } on ApiException catch (err) {
      _toast(err.message);
    } finally {
      if (mounted) setState(() => _working.remove(t.id));
    }
  }

  Future<void> _openScanner() async {
    final e = _event;
    if (e == null) return;
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => ScannerScreen(event: e)));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _loadEvents, child: Text(tr('retry'))),
        ]),
      );
    }
    if (_events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(tr('checkin.noEvents'), textAlign: TextAlign.center),
        ),
      );
    }

    final border = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: cs.outlineVariant),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(tr('checkin.title'),
                  style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(tr('checkin.subtitle'),
                  style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _event?.id,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: tr('checkin.event'),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final e in _events)
                    DropdownMenuItem(
                      value: e.id,
                      child: Text(e.title, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (id) {
                  final e = _events.firstWhere((e) => e.id == id);
                  _selectEvent(e);
                },
              ),
              const SizedBox(height: 14),
              // Stats.
              Row(
                children: [
                  Expanded(child: _StatCard(tr('checkin.registered'), '${_stats.total}')),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _StatCard(tr('checkin.checkedIn'), '${_stats.checkedIn}',
                          accent: Colors.green.shade700)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _StatCard(tr('checkin.notYet'),
                          '${(_stats.total - _stats.checkedIn).clamp(0, 1 << 30)}')),
                ],
              ),
              const SizedBox(height: 14),
              // Manual verification.
              Card(
                margin: EdgeInsets.zero,
                shape: border,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('checkin.verify'),
                          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _code,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _verify(),
                              decoration: InputDecoration(
                                hintText: tr('checkin.code'),
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.confirmation_number_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton(
                            style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
                            onPressed: _verifying ? null : _verify,
                            child: _verifying
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : Text(tr('checkin.verifyBtn')),
                          ),
                        ],
                      ),
                      if (_result != null) ...[
                        const SizedBox(height: 12),
                        _ResultBanner(
                          result: _result!,
                          busy: _result!.ticket != null && _working.contains(_result!.ticket!.id),
                          onUndo: _result!.ticket == null ? null : () => _undo(_result!.ticket!),
                          onClose: () => setState(() => _result = null),
                        ),
                      ],
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _openScanner,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: Text(tr('checkin.scanQr')),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Attendee search.
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _query,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _refresh(),
                      decoration: InputDecoration(
                        hintText: tr('att.hint'),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: cs.surface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
                    onPressed: _searching ? null : _refresh,
                    child: Text(tr('checkin.findBtn')),
                  ),
                ],
              ),
              if (_searching)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: LinearProgressIndicator(),
                ),
              const SizedBox(height: 12),
              if (!_searching && _attendees.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: Text(tr('att.none'))),
                ),
              for (final a in _attendees)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AttendeeCard(
                    ticket: a,
                    busy: _working.contains(a.id),
                    onCheckIn: () => _checkInAttendee(a),
                    onUndo: () => _undo(a),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? accent;
  const _StatCard(this.label, this.value, {this.accent});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(value,
              style: t.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800, color: accent)),
        ],
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  final ScanResult result;
  final bool busy;
  final VoidCallback? onUndo;
  final VoidCallback onClose;
  const _ResultBanner({
    required this.result,
    required this.busy,
    required this.onUndo,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final style = OutcomeStyle.of(result.outcome);
    final tk = result.ticket;
    final usedTime = result.checkedInAt ?? tk?.usedAt;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: style.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(style.icon, color: Colors.white, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(style.title,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: onClose,
              ),
            ],
          ),
          if (tk != null) ...[
            Text(tk.attendeeEmail,
                style: const TextStyle(color: Colors.white, fontSize: 16)),
            Text([tk.ticketTypeName, tk.code].join(' • '),
                style: const TextStyle(color: Colors.white70)),
          ],
          if (result.outcome == ScanOutcome.alreadyUsed && usedTime != null)
            Text(tr('scan.checkedInAt', {'time': formatTime(usedTime)}),
                style: const TextStyle(color: Colors.white70)),
          if (result.message != null)
            Text(result.message!, style: const TextStyle(color: Colors.white)),
          if (result.outcome == ScanOutcome.success && onUndo != null)
            TextButton.icon(
              onPressed: busy ? null : onUndo,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.undo),
              label: Text(tr('scan.undo')),
            ),
        ],
      ),
    );
  }
}

class _AttendeeCard extends StatelessWidget {
  final Ticket ticket;
  final bool busy;
  final VoidCallback onCheckIn;
  final VoidCallback onUndo;
  const _AttendeeCard({
    required this.ticket,
    required this.busy,
    required this.onCheckIn,
    required this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final (label, color) = switch (ticket.status) {
      TicketStatus.valid => (tr('att.notArrived'), Colors.blueGrey),
      TicketStatus.used => (tr('att.arrived'), Colors.green.shade700),
      TicketStatus.cancelled => (tr('ticket.cancelled'), Colors.red.shade700),
    };
    return Material(
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ticket.attendeeEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    '${ticket.ticketTypeName} · ${tr('ticket.number', {'id': ticket.id})}',
                    style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  StatusChip(label, color),
                ],
              ),
            ),
            if (busy)
              const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else if (ticket.status == TicketStatus.valid)
              FilledButton(onPressed: onCheckIn, child: Text(tr('att.checkIn')))
            else if (ticket.status == TicketStatus.used)
              IconButton(
                tooltip: tr('scan.undo'),
                icon: const Icon(Icons.undo),
                onPressed: onUndo,
              ),
          ],
        ),
      ),
    );
  }
}
