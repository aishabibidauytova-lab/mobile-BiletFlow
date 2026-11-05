import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'ticket_screen.dart';

(String, Color) orderStatusLabel(OrderStatus s) {
  switch (s) {
    case OrderStatus.pending:
      return (tr('order.pending'), Colors.orange.shade800);
    case OrderStatus.paid:
      return (tr('order.paid'), Colors.green.shade700);
    case OrderStatus.cancelled:
      return (tr('order.cancelled'), Colors.red.shade700);
    case OrderStatus.expired:
      return (tr('order.expired'), Colors.blueGrey);
  }
}

/// Order details: simulated payment, cancellation and the issued tickets.
class OrderScreen extends StatefulWidget {
  final Order order;
  const OrderScreen({super.key, required this.order});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  late Order _order = widget.order;
  List<Ticket> _tickets = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final o = await api.getOrder(_order.id);
      final tickets = o.status == OrderStatus.paid
          ? (await api.getMyTickets()).where((t) => t.orderId == o.id).toList()
          : <Ticket>[];
      if (mounted) {
        setState(() {
          _order = o;
          _tickets = tickets;
        });
      }
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  void _toast(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _run(Future<Order> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      _order = await action();
      _toast(done);
      await _refresh();
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('order.cancelTitle')),
        content: Text(tr('order.cancelBody')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('no'))),
          FilledButton(
              onPressed: () => Navigator.pop(c, true), child: Text(tr('order.cancel'))),
        ],
      ),
    );
    if (ok == true) _run(() => api.cancelOrder(_order.id), tr('order.cancelled.toast'));
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final (label, color) = orderStatusLabel(o.status);
    final free = o.totalAmount == 0;
    final border = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: cs.outlineVariant),
    );

    return Scaffold(
      appBar: AppBar(title: Text(tr('orders.number', {'id': o.id}))),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                // Status banner.
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          switch (o.status) {
                            OrderStatus.pending => Icons.hourglass_top,
                            OrderStatus.paid => Icons.check_circle,
                            OrderStatus.cancelled => Icons.cancel,
                            OrderStatus.expired => Icons.timer_off,
                          },
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label,
                                style: theme.textTheme.titleMedium?.copyWith(
                                    color: color, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(o.eventTitle,
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            if (o.status == OrderStatus.pending && o.expiresAt != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                    tr('order.reservedUntil', {'date': formatDateTime(o.expiresAt!)}),
                                    style: theme.textTheme.bodySmall),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Receipt.
                Card(
                  margin: EdgeInsets.zero,
                  shape: border,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('order.items'),
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        for (final i in o.items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text('${i.ticketTypeName} × ${i.quantity}'),
                                ),
                                Text(
                                  i.unitPrice == 0
                                      ? tr('free')
                                      : formatPrice(i.unitPrice * i.quantity),
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Text(tr('order.total'),
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800)),
                            ),
                            Text(free ? '0 ₸' : formatPrice(o.totalAmount),
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (o.status == OrderStatus.pending) ...[
                  const SizedBox(height: 14),
                  if (!free)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        border: Border.all(color: Colors.amber.shade700),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.science_outlined, color: Colors.amber.shade900),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(tr('order.demo')),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: _busy
                        ? null
                        : () => _run(() => api.payOrder(o.id),
                            free ? tr('order.confirmedToast') : tr('order.paidToast')),
                    child: Text(free ? tr('order.confirm') : tr('order.pay')),
                  ),
                ],
                if (o.status == OrderStatus.pending || o.status == OrderStatus.paid)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextButton(
                      style: TextButton.styleFrom(foregroundColor: cs.error),
                      onPressed: _busy ? null : _cancel,
                      child: Text(tr('order.cancel')),
                    ),
                  ),
                if (_tickets.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(tr('order.yourTickets'),
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  for (final t in _tickets)
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: border,
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(14, 6, 12, 6),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.qr_code_2, color: cs.onPrimaryContainer),
                        ),
                        title: Text(t.ticketTypeName,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(t.code,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'monospace')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => TicketScreen(ticket: t))),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
