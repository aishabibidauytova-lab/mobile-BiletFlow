import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/date_range_filter.dart';

/// Translated action name; actions added to the server later are shown as-is.
String historyActionLabel(String action) {
  final label = tr('hist.$action');
  return label == 'hist.$action' ? action : label;
}

IconData _icon(String action) {
  if (action.startsWith('PAYMENT') ||
      action.startsWith('PAYOUT') ||
      action.contains('REFUND')) {
    return Icons.payments_outlined;
  }
  if (action.contains('CHECK')) return Icons.how_to_reg_outlined;
  if (action.startsWith('TICKET_TYPE')) return Icons.local_activity_outlined;
  if (action.startsWith('STAFF')) return Icons.badge_outlined;
  if (action.startsWith('PROMO')) return Icons.local_offer_outlined;
  if (action.startsWith('SUPPORT')) return Icons.forum_outlined;
  return Icons.event_note_outlined;
}

/// Activity timeline of one event with date, action and object filters
/// (SRS 4.16). The server returns 50 entries per page.
class EventHistoryScreen extends StatefulWidget {
  final EventInfo event;
  const EventHistoryScreen({super.key, required this.event});

  @override
  State<EventHistoryScreen> createState() => _EventHistoryScreenState();
}

class _EventHistoryScreenState extends State<EventHistoryScreen> {
  final List<HistoryEntry> _entries = [];
  DateTime? _from;
  DateTime? _to;
  String? _action;
  String? _entity;
  int _page = 0;
  bool _last = true;
  bool _loading = true;
  String? _error;
  // Ignores answers that arrive after the filters have changed again.
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    final request = ++_request;
    final page = more ? _page + 1 : 0;
    setState(() {
      _loading = true;
      _error = null;
      if (!more) {
        _entries.clear();
        _last = true;
      }
    });
    try {
      final result = await api.getEventHistory(widget.event.id,
          from: _from,
          to: _to,
          action: _action,
          entityType: _entity,
          page: page);
      if (!mounted || request != _request) return;
      setState(() {
        _entries.addAll(result.items);
        _page = page;
        _last = result.last;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Widget _dropdown(String label, String allLabel, String? value,
          Map<String, String> options, ValueChanged<String?> onChanged) =>
      DropdownButtonFormField<String?>(
        key: ValueKey('$label-$value'),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
            labelText: label,
            isDense: true,
            border: const OutlineInputBorder()),
        items: [
          DropdownMenuItem(value: null, child: Text(allLabel)),
          for (final o in options.entries)
            DropdownMenuItem(
                value: o.key,
                child: Text(o.value, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: onChanged,
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final filtered =
        _from != null || _to != null || _action != null || _entity != null;

    return Scaffold(
      appBar: AppBar(title: Text(tr('hist.title'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              children: [
                Text(widget.event.title,
                    style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                if (widget.event.phase != null)
                  Text(tr('phase.${widget.event.phase}'),
                      style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 12),
                DateRangeFilter(
                  from: _from,
                  to: _to,
                  onChanged: (from, to) {
                    _from = from;
                    _to = to;
                    _load();
                  },
                ),
                const SizedBox(height: 10),
                _dropdown(
                    tr('hist.action'),
                    tr('hist.allActions'),
                    _action,
                    {for (final a in historyActions) a: historyActionLabel(a)},
                    (v) {
                  _action = v;
                  _load();
                }),
                const SizedBox(height: 10),
                _dropdown(
                    tr('hist.entity'),
                    tr('hist.allEntities'),
                    _entity,
                    {
                      for (final x in historyEntityTypes)
                        x: tr('hist.entity.$x')
                    }, (v) {
                  _entity = v;
                  _load();
                }),
                if (filtered)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        _from = _to = null;
                        _action = _entity = null;
                        _load();
                      },
                      child: Text(tr('filter.reset')),
                    ),
                  ),
                const SizedBox(height: 10),
                for (final h in _entries)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(_icon(h.action), color: cs.primary),
                      title: Text(historyActionLabel(h.action),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text([
                        h.description,
                        [
                          if (h.timestamp != null) formatDateTime(h.timestamp!),
                          h.actor,
                        ].where((s) => s.isNotEmpty).join(' • '),
                      ].where((s) => s.isNotEmpty).join('\n')),
                    ),
                  ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null) ...[
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Center(
                    child: OutlinedButton(
                      onPressed: () => _load(more: _entries.isNotEmpty),
                      child: Text(tr('retry')),
                    ),
                  ),
                ] else if (_entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(tr('hist.empty'), textAlign: TextAlign.center),
                  )
                else if (!_last)
                  Center(
                    child: OutlinedButton(
                      onPressed: () => _load(more: true),
                      child: Text(tr('hist.more')),
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
