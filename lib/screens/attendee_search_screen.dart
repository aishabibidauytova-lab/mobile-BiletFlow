import 'dart:async';

import 'package:flutter/material.dart';

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
  List<Attendee> _items = [];
  bool _loading = true;
  String? _error;
  final Set<String> _working = {};

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

  Future<void> _checkIn(Attendee a) async {
    setState(() => _working.add(a.ticketId));
    try {
      final r = await api.checkInByTicketId(widget.event.id, a.ticketId);
      switch (r.outcome) {
        case ScanOutcome.success:
          _toast('Чек-ин выполнен: ${a.name}');
        case ScanOutcome.alreadyUsed:
          _toast('Билет уже использован');
        case ScanOutcome.cancelled:
          _toast('Билет отменён');
        case ScanOutcome.refunded:
          _toast('Билет возвращён');
        default:
          _toast(r.message ?? 'Не удалось выполнить чек-ин');
      }
      await _search(_controller.text);
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _working.remove(a.ticketId));
    }
  }

  Future<void> _undo(Attendee a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Отменить чек-ин?'),
        content: Text('${a.name} (${a.ticketId}) снова станет «не прибыл».'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Нет')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Отменить чек-ин')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _working.add(a.ticketId));
    try {
      await api.undoCheckIn(widget.event.id, a.ticketId);
      _toast('Чек-ин отменён');
      await _search(_controller.text);
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _working.remove(a.ticketId));
    }
  }

  (String, Color) _statusLabel(TicketStatus s) {
    switch (s) {
      case TicketStatus.valid:
        return ('Не прибыл', Colors.blueGrey);
      case TicketStatus.checkedIn:
        return ('Прибыл', Colors.green.shade700);
      case TicketStatus.cancelled:
        return ('Отменён', Colors.red.shade700);
      case TicketStatus.refunded:
        return ('Возврат', Colors.red.shade700);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Поиск участника')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Имя, email или номер билета',
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
                ? const Center(child: Text('Ничего не найдено'))
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final a = _items[i];
                      final (label, color) = _statusLabel(a.status);
                      final busy = _working.contains(a.ticketId);
                      return ListTile(
                        title: Text(a.name),
                        subtitle: Text([
                          a.ticketId,
                          a.ticketType,
                          if (a.seat != null) a.seat!,
                        ].join(' • ')),
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

  Widget _trailing(Attendee a, String label, Color color) {
    switch (a.status) {
      case TicketStatus.valid:
        return FilledButton(
            onPressed: () => _checkIn(a), child: const Text('Чек-ин'));
      case TicketStatus.checkedIn:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(color: color)),
            if (widget.event.canUndo)
              IconButton(
                tooltip: 'Отменить чек-ин',
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
