// Organizer's seating setup (SRS 4.3.1): seating mode, which ticket type each
// section sells, and seats taken out of sale.
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/seat_map_view.dart';

class SeatingSetupScreen extends StatefulWidget {
  final EventInfo event;
  const SeatingSetupScreen({super.key, required this.event});

  @override
  State<SeatingSetupScreen> createState() => _SeatingSetupScreenState();
}

class _SeatingSetupScreenState extends State<SeatingSetupScreen> {
  SeatMap? _map;
  List<TicketType> _types = [];
  String? _error;
  bool _busy = false;
  final _cards = <int, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        api.getSeating(widget.event.id),
        api.getAllTicketTypes(widget.event.id),
      ]);
      if (!mounted) return;
      setState(() {
        _map = results[0] as SeatMap;
        _types = results[1] as List<TicketType>;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  /// Runs a change, then reloads: quantities depend on the assigned sections.
  Future<void> _change(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
    await _load();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _manageSeats(SeatSection section) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              _BlockSeatsScreen(eventId: widget.event.id, section: section)),
    );
    _load();
  }

  Widget _sectionCard(SeatSection s) {
    final t = Theme.of(context).textTheme;
    return Card(
      key: _cards.putIfAbsent(s.id, GlobalKey.new),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${s.name} · ${s.capacity}',
                style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            Text(
              [
                tr(s.seated ? 'seat.kindSeated' : 'seat.kindStanding'),
                tr('seat.free', {'n': s.available}),
                if (s.blocked > 0) tr('seat.blockedN', {'n': s.blocked}),
              ].join(' • '),
              style: t.bodySmall,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int?>(
              key: ValueKey('${s.id}-${s.ticketTypeId}'),
              initialValue: _types.any((x) => x.id == s.ticketTypeId)
                  ? s.ticketTypeId
                  : null,
              isExpanded: true,
              decoration: InputDecoration(
                  labelText: tr('filter.ticketType'),
                  isDense: true,
                  border: const OutlineInputBorder()),
              items: [
                DropdownMenuItem(
                    value: null, child: Text(tr('seat.notForSale'))),
                for (final x in _types)
                  DropdownMenuItem(
                      value: x.id,
                      child: Text('${x.name} · ${formatPrice(x.price)}',
                          overflow: TextOverflow.ellipsis)),
              ],
              onChanged: _busy
                  ? null
                  : (id) => _change(
                      () => api.assignSection(widget.event.id, s.id, id)),
            ),
            if (s.seated)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _busy ? null : () => _manageSeats(s),
                  icon: const Icon(Icons.event_seat_outlined),
                  label: Text(tr('seat.manage')),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final map = _map;
    return Scaffold(
      appBar: AppBar(title: Text(tr('seat.setup'))),
      body: map == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton(
                          onPressed: _load, child: Text(tr('retry'))),
                    ]),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_busy) const LinearProgressIndicator(),
                      Text(tr('seat.setupHint')),
                      const SizedBox(height: 12),
                      SegmentedButton<bool>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(
                              value: false, label: Text(tr('seat.general'))),
                          ButtonSegment(
                              value: true, label: Text(tr('seat.assigned'))),
                        ],
                        selected: {map.assigned},
                        onSelectionChanged: _busy
                            ? null
                            : (v) => _change(() => api.setSeatingMode(
                                widget.event.id,
                                assigned: v.first)),
                      ),
                      if (map.assigned) ...[
                        const SizedBox(height: 16),
                        if (_types.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(tr('seat.needTypes')),
                          ),
                        // Tapping a section scrolls to its settings.
                        HallPlan(
                          map: map,
                          enabled: (_) => true,
                          onTap: (s) {
                            final c = _cards[s.id]?.currentContext;
                            if (c != null) {
                              Scrollable.ensureVisible(c,
                                  duration:
                                      const Duration(milliseconds: 300));
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        for (final s in map.sections) _sectionCard(s),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

/// Take seats of one section out of sale, or put them back.
class _BlockSeatsScreen extends StatefulWidget {
  final int eventId;
  final SeatSection section;
  const _BlockSeatsScreen({required this.eventId, required this.section});

  @override
  State<_BlockSeatsScreen> createState() => _BlockSeatsScreenState();
}

class _BlockSeatsScreenState extends State<_BlockSeatsScreen> {
  List<Seat>? _seats;
  final _selected = <int>{};
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final seats =
          await api.getSectionSeats(widget.eventId, widget.section.id);
      if (!mounted) return;
      setState(() {
        _seats = seats;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  /// Seats that are sold or held by a buyer cannot be changed.
  static bool _editable(Seat s) =>
      s.status == SeatStatus.available || s.status == SeatStatus.unavailable;

  Future<void> _apply(bool blocked) async {
    setState(() => _busy = true);
    try {
      await api.blockSeats(widget.eventId, _selected.toList(), blocked);
      _selected.clear();
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggle(Seat s) => setState(() {
        if (!_selected.remove(s.id) && _selected.length < maxSeatsPerBlock) {
          _selected.add(s.id);
        }
      });

  /// Selects or clears a whole row.
  void _toggleRow(String row) => setState(() {
        final ids = [
          for (final s in _seats!)
            if (s.row == row && _editable(s)) s.id,
        ];
        if (_selected.containsAll(ids)) {
          _selected.removeAll(ids);
        } else {
          for (final id in ids) {
            if (_selected.length < maxSeatsPerBlock) _selected.add(id);
          }
        }
      });

  @override
  Widget build(BuildContext context) {
    final seats = _seats;
    final rows = {for (final s in seats ?? const <Seat>[]) s.row};
    final idle = !_busy && _selected.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(widget.section.name)),
      body: seats == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton(
                          onPressed: _load, child: Text(tr('retry'))),
                    ]),
            )
          : Column(
              children: [
                if (_busy) const LinearProgressIndicator(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(tr('seat.blockHint')),
                ),
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    children: [
                      for (final r in rows)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(tr('seat.row', {'row': r})),
                            onPressed: () => _toggleRow(r),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ClipRect(
                    child: SeatGrid(
                      seats: seats,
                      selected: _selected,
                      enabled: _editable,
                      onTap: _toggle,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: SeatLegend(),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: idle ? () => _apply(true) : null,
                  child: Text('${tr('seat.block')} (${_selected.length})'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: idle ? () => _apply(false) : null,
                  child: Text(tr('seat.unblock')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
