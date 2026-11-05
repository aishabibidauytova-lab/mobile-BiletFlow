import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/event_poster.dart';
import 'order_screen.dart';

/// Event page: details, ticket types, quantity selection, order creation.
class EventDetailScreen extends StatefulWidget {
  final EventInfo event;
  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late Future<List<TicketType>> _future;
  final Map<int, int> _qty = {};
  bool _ordering = false;

  @override
  void initState() {
    super.initState();
    _future = api.getTicketTypes(widget.event.id);
  }

  bool get _registrationClosed {
    final close = widget.event.registrationClosingTime;
    return widget.event.isCancelled ||
        (close != null && DateTime.now().isAfter(close));
  }

  num _total(List<TicketType> types) => types.fold<num>(
      0, (sum, t) => sum + t.price * (_qty[t.id] ?? 0));

  int get _count => _qty.values.fold(0, (a, b) => a + b);

  Future<void> _order() async {
    setState(() => _ordering = true);
    try {
      final order = await api.createOrder(widget.event.id, _qty);
      if (!mounted) return;
      setState(() => _qty.clear());
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OrderScreen(order: order)),
      );
      if (mounted) setState(() => _future = api.getTicketTypes(widget.event.id));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
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
                                else
                                  for (final t in types)
                                    _TicketTypeTile(
                                      type: t,
                                      quantity: _qty[t.id] ?? 0,
                                      enabled: !_registrationClosed && t.onSale,
                                      onChanged: (q) => setState(() => _qty[t.id] = q),
                                    ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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
                            onPressed: _ordering ? null : _order,
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

  const _TicketTypeTile({
    required this.type,
    required this.quantity,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final max = type.available < type.maxPerOrder ? type.available : type.maxPerOrder;
    final String note;
    if (type.available <= 0) {
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
      ),
    );
  }
}
