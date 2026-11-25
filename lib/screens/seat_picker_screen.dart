import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/scrolling.dart';
import '../widgets/seat_map_view.dart';

/// Attendee's seat selection (SRS 4.3.1): pick a section, then its seats.
/// Pops with the selection, keyed by seat id.
class SeatPickerScreen extends StatefulWidget {
  final EventInfo event;
  final List<TicketType> types;
  final Map<int, SelectedSeat> selected;

  /// Standing tickets already chosen, per ticket type: they count towards the
  /// per-order limit of that type.
  final Map<int, int> quantities;

  /// Open the first section selling this ticket type.
  final int? ticketTypeId;
  const SeatPickerScreen({
    super.key,
    required this.event,
    required this.types,
    this.selected = const {},
    this.quantities = const {},
    this.ticketTypeId,
  });

  @override
  State<SeatPickerScreen> createState() => _SeatPickerScreenState();
}

class _SeatPickerScreenState extends State<SeatPickerScreen> {
  late final Map<int, SelectedSeat> _selected = Map.of(widget.selected);
  SeatMap? _map;
  SeatSection? _section;
  List<Seat>? _seats;
  String? _error;
  // Ignores answers for a section the user has already left.
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _loadMap();
  }

  void _toast(String msg) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _loadMap() async {
    setState(() => _error = null);
    try {
      final map = await api.getSeatMap(widget.event.id);
      if (!mounted) return;
      final wanted = _section?.id;
      final matches = map.sections.where((s) => wanted != null
          ? s.id == wanted
          : s.selectable &&
              (widget.ticketTypeId == null ||
                  s.ticketTypeId == widget.ticketTypeId));
      setState(() => _map = map);
      if (matches.isNotEmpty) _open(matches.first);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _open(SeatSection section) async {
    final request = ++_request;
    setState(() {
      _section = section;
      _seats = null;
      _error = null;
    });
    try {
      final seats = await api.getSectionSeats(widget.event.id, section.id);
      if (!mounted || request != _request) return;
      // Seats picked earlier may have been taken by someone else since.
      final free = {
        for (final s in seats)
          if (s.status == SeatStatus.available) s.id,
      };
      final gone = [
        for (final s in _selected.values)
          if (s.sectionId == section.id && !free.contains(s.id)) s.id,
      ];
      setState(() {
        _seats = seats;
        gone.forEach(_selected.remove);
      });
      if (gone.isNotEmpty) _toast(tr('seat.gone'));
    } on ApiException catch (e) {
      if (mounted && request == _request) setState(() => _error = e.message);
    }
  }

  void _toggle(Seat seat) {
    final section = _section!;
    if (_selected.containsKey(seat.id)) {
      setState(() => _selected.remove(seat.id));
      return;
    }
    final matches = widget.types.where((t) => t.id == section.ticketTypeId);
    final type = matches.isEmpty ? null : matches.first;
    if (type == null || !type.onSale) {
      _toast(tr('ticketType.closed'));
      return;
    }
    final ofType = (widget.quantities[type.id] ?? 0) +
        _selected.values.where((s) => s.ticketTypeId == type.id).length;
    final max =
        type.available < type.maxPerOrder ? type.available : type.maxPerOrder;
    if (ofType >= max) {
      _toast(tr('seat.typeLimit', {'name': type.name, 'n': max}));
      return;
    }
    if (_selected.length >= maxSeatsPerOrder) {
      _toast(tr('seat.orderLimit', {'n': maxSeatsPerOrder}));
      return;
    }
    setState(() => _selected[seat.id] = SelectedSeat(
          id: seat.id,
          sectionId: section.id,
          sectionName: section.name,
          row: seat.row,
          number: seat.number,
          ticketTypeId: type.id,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final map = _map;
    final section = _section;
    final seats = _seats;
    final t = Theme.of(context).textTheme;
    final price = {for (final tt in widget.types) tt.id: tt.price};
    final total = _selected.values
        .fold<num>(0, (sum, s) => sum + (price[s.ticketTypeId] ?? 0));
    final picked = <int, int>{};
    for (final s in _selected.values) {
      picked[s.sectionId] = (picked[s.sectionId] ?? 0) + 1;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('seat.choose')),
        actions: [
          IconButton(
            tooltip: tr('seat.refresh'),
            icon: const Icon(Icons.refresh),
            onPressed: _loadMap,
          ),
        ],
      ),
      body: map == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton(
                          onPressed: _loadMap, child: Text(tr('retry'))),
                    ]),
            )
          // The page itself does not scroll: dragging belongs to the seats.
          : LayoutBuilder(builder: (context, box) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: box.maxHeight * 0.28,
                      child: HallPlan(
                        map: map,
                        activeSectionId: section?.id,
                        picked: picked,
                        enabled: (s) =>
                            s.selectable || picked.containsKey(s.id),
                        onTap: _open,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (section == null)
                      Expanded(
                        child: Center(
                          child: Text(tr('seat.pickSection'),
                              textAlign: TextAlign.center),
                        ),
                      )
                    else ...[
                      Text(
                        [
                          section.name,
                          ?section.ticketTypeName,
                          if (section.price != null)
                            formatPrice(section.price!),
                        ].join(' · '),
                        style: t.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(tr('seat.dragHint'), style: t.bodySmall),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Container(
                          clipBehavior: Clip.hardEdge,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant),
                          ),
                          child: _error != null
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(_error!,
                                          textAlign: TextAlign.center),
                                      TextButton(
                                          onPressed: () => _open(section),
                                          child: Text(tr('retry'))),
                                    ],
                                  ),
                                )
                              : seats == null
                                  ? const Center(
                                      child: CircularProgressIndicator())
                                  : SeatGrid(
                                      key: ValueKey(section.id),
                                      seats: seats,
                                      selected: _selected.keys.toSet(),
                                      enabled: (s) =>
                                          s.status == SeatStatus.available ||
                                          _selected.containsKey(s.id),
                                      onTap: _toggle,
                                    ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const SizedBox(
                        height: 22,
                        child: HorizontalStrip(children: [SeatLegend()]),
                      ),
                    ],
                    if (_selected.isNotEmpty)
                      SizedBox(
                        height: 52,
                        child: HorizontalStrip(
                          children: [
                            for (final s in _selected.values)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: InputChip(
                                  label: Text(s.label),
                                  onDeleted: () =>
                                      setState(() => _selected.remove(s.id)),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            }),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed:
                map == null ? null : () => Navigator.pop(context, _selected),
            child: Text(_selected.isEmpty
                ? tr('seat.done')
                : '${tr('seat.done')} · ${_selected.length} · '
                    '${formatPrice(total)}'),
          ),
        ),
      ),
    );
  }
}
