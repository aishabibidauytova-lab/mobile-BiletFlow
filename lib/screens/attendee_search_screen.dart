import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class AttendeeSearchScreen extends StatefulWidget {
  final EventInfo event;
  const AttendeeSearchScreen({super.key, required this.event});

  @override
  State<AttendeeSearchScreen> createState() => _AttendeeSearchScreenState();
}

class _AttendeeSearchScreenState extends State<AttendeeSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Ticket> _items = [];
  bool _loading = true;
  String? _error;
  final Set<int> _working = {};

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String q) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await api.searchAttendees(widget.event.id, q);
      if (!mounted) return;
      setState(() => _items = r);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _checkIn(Ticket a) async {
    setState(() => _working.add(a.id));
    try {
      final r = await api.checkIn(widget.event.id, a.code);
      switch (r.outcome) {
        case ScanOutcome.success:
          _toast(tr('att.checkedIn', {'email': a.attendeeEmail}));
        case ScanOutcome.alreadyUsed:
          _toast(tr('att.alreadyUsed'));
        case ScanOutcome.cancelled:
          _toast(tr('att.cancelled'));
        default:
          _toast(r.message ?? tr('att.failed'));
      }
      await _search(_controller.text);
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _working.remove(a.id));
    }
  }

  Future<void> _undo(Ticket a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('att.undoTitle')),
        content: Text(tr('att.undoBody', {'email': a.attendeeEmail, 'code': a.code})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(tr('no'))),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(tr('scan.undo'))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _working.add(a.id));
    try {
      await api.undoCheckIn(widget.event.id, a.id);
      _toast(tr('scan.undone'));
      await _search(_controller.text);
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _working.remove(a.id));
    }
  }

  (String, Color) _statusLabel(TicketStatus s) {
    switch (s) {
      case TicketStatus.valid:
        return (tr('att.notArrived'), Colors.blueGrey);
      case TicketStatus.used:
        return (tr('att.arrived'), Colors.green.shade700);
      case TicketStatus.cancelled:
        return (tr('ticket.cancelled'), Colors.red.shade700);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('scan.search'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: tr('att.hint'),
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          _search('');
                        },
                      ),
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          Expanded(
            child: !_loading && _items.isEmpty && _error == null
                ? Center(child: Text(tr('att.none')))
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final a = _items[i];
                      final (label, color) = _statusLabel(a.status);
                      final busy = _working.contains(a.id);
                      return ListTile(
                        title: Text(a.attendeeEmail),
                        subtitle: Text([a.code, a.ticketTypeName].join(' • ')),
                        trailing: busy
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : _trailing(a, label, color),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _trailing(Ticket a, String label, Color color) {
    switch (a.status) {
      case TicketStatus.valid:
        return FilledButton(
            onPressed: () => _checkIn(a), child: Text(tr('att.checkIn')));
      case TicketStatus.used:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(color: color)),
            IconButton(
                tooltip: tr('scan.undo'),
                icon: const Icon(Icons.undo),
                onPressed: () => _undo(a),
              ),
          ],
        );
      default:
        return Chip(
          label: Text(label, style: const TextStyle(color: Colors.white)),
          backgroundColor: color,
        );
    }
  }
}
