import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/calendar_button.dart';
import '../widgets/event_poster.dart';
import '../widgets/report_event_dialog.dart';
import 'checkout_sheet.dart';
import 'order_screen.dart';
import 'seat_picker_screen.dart';

/// Event page: details, ticket types, quantity selection, order creation.
class EventDetailScreen extends StatefulWidget {
  final EventInfo event;

  /// Organizer's look at the page before publishing: nothing can be ordered.
  /// A draft gets a publish button, which pops with the published event.
  final bool preview;

  /// Promo code or token carried by a campaign link.
  final String? promo;
  const EventDetailScreen(
      {super.key, required this.event, this.preview = false, this.promo});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late Future<List<TicketType>> _future;
  final Map<int, int> _qty = {};
  final Map<int, SelectedSeat> _seats = {};
  SeatMap? _map; // Only for events with assigned seating.
  bool _ordering = false;
  bool _publishing = false;
  PromoPreview? _promo;
  String? _promoError;

  @override
  void initState() {
    super.initState();
    _future = _load();
    if (widget.promo != null) _loadPromo(widget.promo!);
  }

  Future<List<TicketType>> _load() async {
    final types = await api.getTicketTypes(widget.event.id);
    if (widget.event.assignedSeating) {
      _map = await api.getSeatMap(widget.event.id);
    }
    return types;
  }

  /// Whether this ticket type is bought by picking seats on the map. A type
  /// that also covers a standing zone is bought by count.
  bool _bySeat(TicketType t) {
    final sections = _map?.sectionsOf(t.id) ?? const <SeatSection>[];
    return sections.isNotEmpty && sections.every((s) => s.seated);
  }

  /// With assigned seating, a type without a section is not on sale.
  bool _unassigned(TicketType t) =>
      widget.event.assignedSeating && (_map?.sectionsOf(t.id).isEmpty ?? true);

  int _seatCount(int typeId) =>
      _seats.values.where((s) => s.ticketTypeId == typeId).length;

  Future<void> _pickSeats(List<TicketType> types, [int? typeId]) async {
    final picked = await Navigator.push<Map<int, SelectedSeat>>(
      context,
      MaterialPageRoute(
        builder: (_) => SeatPickerScreen(
          event: widget.event,
          types: types,
          selected: _seats,
          quantities: _qty,
          ticketTypeId: typeId,
        ),
      ),
    );
    if (!mounted) return;
    // A limit notice from the map must not cover the order button.
    ScaffoldMessenger.of(context).clearSnackBars();
    if (picked == null) return;
    setState(() => _seats
      ..clear()
      ..addAll(picked));
  }

  Future<void> _loadPromo(String value) async {
    try {
      final p = await api.previewPromo(widget.event.id, value);
      if (mounted) setState(() => _promo = p);
    } on ApiException catch (e) {
      if (mounted) setState(() => _promoError = e.message);
    }
  }

  Future<void> _publish() async {
    setState(() => _publishing = true);
    try {
      final published = await api.publishEvent(widget.event.id);
      if (mounted) Navigator.pop(context, published);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
      setState(() => _publishing = false);
    }
  }

  bool get _registrationClosed {
    final close = widget.event.registrationClosingTime;
    return widget.event.isCancelled ||
        widget.event.suspended ||
        (close != null && DateTime.now().isAfter(close));
  }

  num _total(List<TicketType> types) => types.fold<num>(0,
      (sum, t) => sum + t.price * ((_qty[t.id] ?? 0) + _seatCount(t.id)));

  int get _count => _qty.values.fold(_seats.length, (a, b) => a + b);

  Future<void> _order(List<TicketType> types) async {
    setState(() => _ordering = true);
    try {
      // Attendee name, promo code and price preview, then the order is created.
      final order = await showCheckoutSheet(context,
          event: widget.event,
          quantities: Map.of(_qty),
          types: types,
          seats: _seats.values.toList(),
          promoCode: _promo?.code);
      if (order == null || !mounted) return;
      setState(() {
        _qty.clear();
        _seats.clear();
      });
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OrderScreen(order: order)),
      );
      if (mounted) setState(() => _future = _load());
    } finally {
      if (mounted) setState(() => _ordering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      body: FutureBuilder<List<TicketType>>(
        future: _future,
        builder: (context, snap) {
          final types = snap.data ?? const <TicketType>[];
          return Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      pinned: true,
                      expandedHeight: 280,
                      backgroundColor: cs.surface,
                      foregroundColor: Colors.white,
                      iconTheme: const IconThemeData(color: Colors.white),
                      actions: [
                        if (!widget.preview)
                          IconButton(
                            tooltip: tr('report.action'),
                            icon: const Icon(Icons.flag_outlined),
                            onPressed: () => showReportEventDialog(context, e.id),
                          ),
                      ],
                      flexibleSpace: FlexibleSpaceBar(
                        collapseMode: CollapseMode.parallax,
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            EventPoster(event: e),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Color(0x66000000), Colors.transparent],
                                  stops: [0, 0.4],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widget.preview)
                                  _Banner(Icons.visibility_outlined,
                                      tr('preview.banner'), cs.tertiaryContainer),
                                if (_promo != null)
                                  _Banner(
                                      Icons.local_offer_outlined,
                                      tr('link.promoReady', {
                                        'code': _promo!.code,
                                        'discount': _promo!.discountLabel,
                                      }),
                                      Colors.green.shade50),
                                if (_promoError != null)
                                  _Banner(
                                      Icons.error_outline,
                                      tr('link.promoInvalid', {'msg': _promoError}),
                                      cs.errorContainer),
                                if (e.category.isNotEmpty)
                                  Chip(
                                    avatar: Icon(categoryIcon(e.category),
                                        size: 16, color: cs.primary),
                                    label: Text(categoryLabel(e.category)),
                                    visualDensity: VisualDensity.compact,
                                    side: BorderSide.none,
                                    backgroundColor: cs.primaryContainer,
                                  ),
                                const SizedBox(height: 10),
                                Text(e.title,
                                    style: theme.textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.w800, height: 1.15)),
                                const SizedBox(height: 18),
                                if (e.startTime != null)
                                  _InfoCard(
                                    icon: Icons.event,
                                    title: formatDateTime(e.startTime!).substring(0, 10),
                                    subtitle: [
                                      formatTime(e.startTime!),
                                      if (e.endTime != null) formatTime(e.endTime!),
                                    ].join(' – '),
                                  ),
                                if (e.venue != null)
                                  _InfoCard(
                                    icon: Icons.place,
                                    title: e.venue!.name,
                                    subtitle: e.venue!.address,
                                  ),
                                if (e.description.isNotEmpty) ...[
                                  const SizedBox(height: 20),
                                  Text(tr('detail.about'),
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 8),
                                  Text(e.description,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(height: 1.45)),
                                ],
                                const SizedBox(height: 28),
                                Text(tr('detail.tickets'),
                                    style: theme.textTheme.titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w800)),
                                const SizedBox(height: 10),
                                if (_registrationClosed)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        Icon(Icons.info_outline,
                                            size: 18, color: cs.error),
                                        const SizedBox(width: 6),
                                        Text(
                                          e.isCancelled
                                              ? tr('detail.cancelled')
                                              : e.suspended
                                                  ? tr('detail.suspended')
                                                  : tr('detail.closed'),
                                          style: TextStyle(color: cs.error),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (snap.connectionState != ConnectionState.done)
                                  const Center(
                                      child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(),
                                  ))
                                else if (snap.hasError)
                                  Text(snap.error is ApiException
                                      ? (snap.error as ApiException).message
                                      : tr('detail.ticketsFailed'))
                                else if (types.isEmpty)
                                  Text(tr('detail.noSale'))
                                else ...[
                                  if (widget.event.assignedSeating)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                            minimumSize:
                                                const Size.fromHeight(48)),
                                        onPressed: widget.preview ||
                                                _registrationClosed
                                            ? null
                                            : () => _pickSeats(types),
                                        icon: const Icon(
                                            Icons.event_seat_outlined),
                                        label: Text(tr('seat.choose')),
                                      ),
                                    ),
                                  for (final t in types)
                                    _TicketTypeTile(
                                      type: t,
                                      quantity: _bySeat(t)
                                          ? _seatCount(t.id)
                                          : _qty[t.id] ?? 0,
                                      enabled: !widget.preview &&
                                          !_registrationClosed &&
                                          !_unassigned(t) &&
                                          t.onSale,
                                      note: _unassigned(t)
                                          ? tr('seat.notForSale')
                                          : null,
                                      onPickSeats: _bySeat(t)
                                          ? () => _pickSeats(types, t.id)
                                          : null,
                                      onChanged: (q) => setState(() => _qty[t.id] = q),
                                    ),
                                  if (_seats.isNotEmpty)
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        for (final s in _seats.values)
                                          InputChip(
                                            label: Text(s.label),
                                            onDeleted: () => setState(
                                                () => _seats.remove(s.id)),
                                          ),
                                      ],
                                    ),
                                ],
                                if (!widget.preview &&
                                    e.status != 'DRAFT') ...[
                                  const SizedBox(height: 10),
                                  CalendarButton(eventId: e.id),
                                ],
                                if ((e.refundPolicy ?? '').trim().isNotEmpty) ...[
                                  const SizedBox(height: 20),
                                  Text(tr('policy.title'),
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 8),
                                  Text(e.refundPolicy!.trim(),
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(height: 1.45)),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.preview)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                    child: e.status == 'DRAFT'
                        ? FilledButton.icon(
                            style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(50)),
                            onPressed: _publishing ? null : _publish,
                            icon: const Icon(Icons.publish),
                            label: Text(tr('preview.publish')),
                          )
                        : OutlinedButton(
                            style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(50)),
                            onPressed: () => Navigator.pop(context),
                            child: Text(tr('preview.back')),
                          ),
                  ),
                ),
              if (_count > 0)
                Material(
                  elevation: 12,
                  color: cs.surface,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(tr('detail.ticketCount', {'n': _count}),
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(color: cs.onSurfaceVariant)),
                                Text(
                                  _total(types) == 0
                                      ? tr('free')
                                      : formatPrice(_total(types)),
                                  style: theme.textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                            ),
                            onPressed: _ordering ? null : () => _order(types),
                            child: _ordering
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : Text(_total(types) == 0
                                    ? tr('detail.register')
                                    : tr('detail.order')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _Banner(this.icon, this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      );
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _InfoCard({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketTypeTile extends StatelessWidget {
  final TicketType type;
  final int quantity;
  final bool enabled;
  final ValueChanged<int> onChanged;

  /// Replaces the availability line.
  final String? note;

  /// Set for seated tickets: the counter gives way to the seat map.
  final VoidCallback? onPickSeats;

  const _TicketTypeTile({
    required this.type,
    required this.quantity,
    required this.enabled,
    required this.onChanged,
    this.note,
    this.onPickSeats,
  });

  @override
  Widget build(BuildContext context) {
    final max = type.available < type.maxPerOrder ? type.available : type.maxPerOrder;
    final String note;
    if (this.note != null) {
      note = this.note!;
    } else if (type.available <= 0) {
      note = tr('ticketType.soldOut');
    } else if (!type.onSale) {
      note = tr('ticketType.closed');
    } else {
      note = tr('ticketType.left', {'n': type.available});
    }
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final selected = quantity > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: selected ? cs.primaryContainer.withValues(alpha: 0.45) : cs.surface,
        border: Border.all(
          color: selected ? cs.primary : cs.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type.name,
                    style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  formatPrice(type.price),
                  style: t.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: type.isFree ? const Color(0xFF16A34A) : cs.primary),
                ),
                if (type.description.isNotEmpty)
                  Text(type.description,
                      style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(note,
                    style: t.bodySmall?.copyWith(
                        color: enabled ? cs.onSurfaceVariant : cs.error)),
              ],
            ),
          ),
          if (onPickSeats != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.tonalIcon(
                onPressed: enabled ? onPickSeats : null,
                icon: const Icon(Icons.event_seat_outlined, size: 18),
                label: Text('$quantity'),
              ),
            )
          else ...[
          IconButton.filledTonal(
            tooltip: tr('ticketType.less'),
            onPressed: enabled && quantity > 0 ? () => onChanged(quantity - 1) : null,
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 32,
            child: Text('$quantity',
                textAlign: TextAlign.center,
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          IconButton.filled(
            tooltip: tr('ticketType.more'),
            onPressed: enabled && quantity < max ? () => onChanged(quantity + 1) : null,
            icon: const Icon(Icons.add),
          ),
          ],
        ],
      ),
    );
  }
}
