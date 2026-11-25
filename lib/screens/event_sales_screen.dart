import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/async_list.dart';
import '../widgets/date_range_filter.dart';
import 'order_screen.dart' show orderStatusLabel;

/// Sales of one event (SRS 4.15), calculated by the server from orders:
/// revenue, discounts, fees, estimated payout, ticket types, daily sales, orders.
class EventSalesScreen extends StatefulWidget {
  final int eventId;
  final String title;
  const EventSalesScreen({super.key, required this.eventId, required this.title});

  @override
  State<EventSalesScreen> createState() => _EventSalesScreenState();
}

class _EventSalesScreenState extends State<EventSalesScreen> {
  DateTime? _from;
  DateTime? _to;
  int? _typeId;
  late Future<EventSales> _future = _loadSales();
  late Future<Attendance> _attendance = _loadAttendance();

  Future<EventSales> _loadSales() => api.getEventSales(widget.eventId,
      from: _from, to: _to, ticketTypeId: _typeId);

  Future<Attendance> _loadAttendance() =>
      api.getAttendance(widget.eventId, ticketTypeId: _typeId);

  void _reload() => setState(() {
        _future = _loadSales();
        _attendance = _loadAttendance();
      });

  void _filter(DateTime? from, DateTime? to, int? typeId) {
    _from = from;
    _to = to;
    _typeId = typeId;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title, overflow: TextOverflow.ellipsis),
          bottom: TabBar(tabs: [
            Tab(text: tr('sales.title')),
            Tab(text: tr('sales.orders')),
          ]),
        ),
        body: TabBarView(
          children: [
            FutureBuilder<EventSales>(
              future: _future,
              builder: (context, snap) {
                final loading = snap.connectionState != ConnectionState.done;
                // While filtering, the previous figures stay on screen.
                if (loading && !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  final err = snap.error;
                  return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(err is ApiException ? err.message : tr('err.load')),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _reload,
                        child: Text(tr('retry')),
                      ),
                    ]),
                  );
                }
                return Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: () async {
                        _reload();
                        await _future.then((_) {}, onError: (_) {});
                      },
                      child: _SalesBody(
                        sales: snap.data!,
                        attendance: _attendance,
                        from: _from,
                        to: _to,
                        typeId: _typeId,
                        onFilter: _filter,
                      ),
                    ),
                    if (loading) const LinearProgressIndicator(),
                  ],
                );
              },
            ),
            _OrdersTab(eventId: widget.eventId, onRefund: _reload),
          ],
        ),
      ),
    );
  }
}

/// Figures shared by the per-event screen and the organizer's sales tab.
class SalesFiguresGrid extends StatelessWidget {
  final SalesFigures f;
  final int? capacity;
  const SalesFiguresGrid({super.key, required this.f, this.capacity});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      (tr('sales.sold'), capacity == null ? '${f.ticketsSold}' : '${f.ticketsSold} / $capacity'),
      (tr('sales.reserved'), '${f.ticketsReserved}'),
      (tr('sales.paidOrders'), '${f.paidOrders}'),
      (tr('sales.revenue'), formatPrice(f.revenue)),
      (tr('sales.discounts'), formatPrice(f.discounts)),
      (tr('sales.net'), formatPrice(f.netRevenue)),
      (tr('refund.total'), formatPrice(f.refunds)),
      (tr('sales.fees'), formatPrice(f.processingFees)),
      (tr('sales.payout'), formatPrice(f.estimatedPayout)),
    ];
    return LayoutBuilder(builder: (context, c) {
      final perRow = c.maxWidth > 560 ? 4 : 2;
      final w = (c.maxWidth - (perRow - 1) * 10) / perRow;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final (label, value) in tiles)
            SizedBox(width: w, child: _StatTile(label, value)),
        ],
      );
    });
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  const _StatTile(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _SalesBody extends StatelessWidget {
  final EventSales sales;
  final Future<Attendance> attendance;
  final DateTime? from;
  final DateTime? to;
  final int? typeId;
  final void Function(DateTime? from, DateTime? to, int? typeId) onFilter;
  const _SalesBody({
    required this.sales,
    required this.attendance,
    required this.from,
    required this.to,
    required this.typeId,
    required this.onFilter,
  });

  Widget _filters(BuildContext context) {
    final filtered = from != null || to != null || typeId != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DateRangeFilter(
            from: from, to: to, onChanged: (f, t) => onFilter(f, t, typeId)),
        const SizedBox(height: 8),
        DropdownButtonFormField<int?>(
          key: ValueKey(typeId),
          initialValue: typeId,
          isExpanded: true,
          decoration: InputDecoration(
              labelText: tr('filter.ticketType'),
              isDense: true,
              border: const OutlineInputBorder()),
          items: [
            DropdownMenuItem(value: null, child: Text(tr('filter.allTypes'))),
            for (final tt in sales.ticketTypes)
              DropdownMenuItem(value: tt.id, child: Text(tt.name)),
          ],
          onChanged: (v) => onFilter(from, to, v),
        ),
        const SizedBox(height: 6),
        Text(tr('filter.scope'), style: Theme.of(context).textTheme.bodySmall),
        if (filtered)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => onFilter(null, null, null),
              child: Text(tr('filter.reset')),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final days = sales.salesByDay;
    final maxRevenue = days.fold<num>(0, (m, d) => d.revenue > m ? d.revenue : m);
    final maxSold = days.fold<int>(0, (m, d) => d.ticketsSold > m ? d.ticketsSold : m);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SalesFiguresGrid(f: sales.figures, capacity: sales.capacity),
        const SizedBox(height: 16),
        _filters(context),
        const SizedBox(height: 12),
        _AttendanceSection(future: attendance),
        const SizedBox(height: 16),
        Text(tr('sales.byType'), style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (final tt in sales.ticketTypes
            .where((x) => typeId == null || x.id == typeId))
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(tt.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('sales.typeLine', {
                    'sold': tt.sold,
                    'qty': tt.quantity,
                    'reserved': tt.reserved,
                    'left': tt.available,
                  })),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: tt.quantity == 0 ? 0 : tt.sold / tt.quantity,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
              trailing: Text(formatPrice(tt.revenue),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        const SizedBox(height: 16),
        Text(tr('sales.byDay'), style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (from != null || to != null || typeId != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              tr('filter.period', {
                'sold': days.fold<int>(0, (n, d) => n + d.ticketsSold),
                'revenue': days.isEmpty
                    ? '0 ₸'
                    : formatPrice(days.fold<num>(0, (n, d) => n + d.revenue)),
              }),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        if (days.isEmpty)
          Text(tr('sales.noSales'), style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant))
        else
          for (final d in days)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 84,
                    child: Text(d.date == null ? '—' : formatDateTime(d.date!).substring(0, 10),
                        style: t.bodySmall),
                  ),
                  Expanded(
                    child: Semantics(
                      label: '${d.ticketsSold} • ${formatPrice(d.revenue)}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          // Free events: scale by tickets instead of revenue.
                          value: maxRevenue > 0
                              ? d.revenue / maxRevenue
                              : (maxSold == 0 ? 0 : d.ticketsSold / maxSold),
                          minHeight: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 104,
                    child: Text('${d.ticketsSold} • ${formatPrice(d.revenue)}',
                        textAlign: TextAlign.right, style: t.bodySmall),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// Check-in and absent counts of the event (SRS 4.15).
class _AttendanceSection extends StatelessWidget {
  final Future<Attendance> future;
  const _AttendanceSection({required this.future});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr('att.title'),
            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        FutureBuilder<Attendance>(
          future: future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const LinearProgressIndicator();
            }
            final a = snap.data;
            if (a == null) {
              final err = snap.error;
              return Text(err is ApiException ? err.message : tr('err.load'));
            }
            return LayoutBuilder(builder: (context, c) {
              final w = (c.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final (label, value) in [
                    (tr('att.holders'), '${a.ticketHolders}'),
                    (tr('att.checkedIn'), '${a.checkedIn}'),
                    (tr('att.absent'), '${a.absent}'),
                    (tr('att.rate'), '${a.percent}%'),
                  ])
                    SizedBox(width: w, child: _StatTile(label, value)),
                ],
              );
            });
          },
        ),
      ],
    );
  }
}

class _OrdersTab extends StatefulWidget {
  final int eventId;
  final VoidCallback onRefund;
  const _OrdersTab({required this.eventId, required this.onRefund});

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  final _list = GlobalKey<AsyncListState<EventOrder>>();
  final _query = TextEditingController();
  Timer? _debounce;
  String? _status;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  final _inProgress = <int>{};

  Future<void> _refund(EventOrder order) async {
    if (!_inProgress.add(order.id)) return;
    setState(() {});
    final label = tr(order.totalAmount == 0 ? 'refund.free' : 'refund.action');
    var reason = '';
    try {
      final confirmed = await showDialog<bool>(context: context, builder: (dialog) =>
        AlertDialog(title: Text(label), content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(tr('refund.confirm', {'id': order.id, 'amount': formatPrice(order.totalAmount)})),
          TextField(maxLength: 500, onChanged: (value) => reason = value,
            decoration: InputDecoration(labelText: tr('refund.reason'))),
        ]), actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(tr('no'))),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(label)),
        ]));
      if (confirmed != true || !mounted) return;
      await api.refundOrder(order.id, reason);
      if (!mounted) return;
      widget.onRefund();
      await _list.currentState?.reload();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        _reload();
      }
    } finally {
      _inProgress.remove(order.id);
      if (mounted) setState(() {});
    }
  }

  void _reload() => _list.currentState?.reload();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: TextField(
            controller: _query,
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 400), _reload);
            },
            decoration: InputDecoration(
              hintText: tr('sales.searchOrders'),
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (final s in [null, ...OrderStatus.values])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(s == null ? tr('support.all') : orderStatusLabel(s).$1),
                    selected: _status == s?.name.toUpperCase(),
                    onSelected: (_) {
                      setState(() => _status = s?.name.toUpperCase());
                      _reload();
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: AsyncList<EventOrder>(
            key: _list,
            load: () =>
                api.getEventOrders(widget.eventId, status: _status, query: _query.text),
            emptyText: tr('sales.noOrders'),
            itemBuilder: (context, o) {
              final (label, color) = orderStatusLabel(o.status);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(o.attendeeName?.isNotEmpty == true
                      ? '${o.attendeeName} · ${o.buyerEmail}'
                      : o.buyerEmail),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text([
                    tr('orders.number', {'id': o.id}),
                    tr('orders.ticketsN', {'n': o.ticketCount}),
                    if (o.promoCode != null) '${o.promoCode} −${formatPrice(o.discountAmount)}',
                    if (o.createdAt != null) formatDateTime(o.createdAt!),
                  ].join(' • ')),
                    if (o.status == OrderStatus.paid) TextButton(
                      onPressed: _inProgress.contains(o.id) ? null : () => _refund(o),
                      child: Text(tr(o.totalAmount == 0 ? 'refund.free' : 'refund.action'))),
                  ]),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(o.totalAmount == 0 ? tr('free') : formatPrice(o.totalAmount),
                          style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurface)),
                      const SizedBox(height: 4),
                      StatusChip(label, color),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
