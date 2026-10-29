import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import 'ticket_screen.dart';

(String, Color) orderStatusLabel(OrderStatus s) {
  switch (s) {
    case OrderStatus.pending:
      return ('Ожидает оплаты', Colors.orange.shade800);
    case OrderStatus.paid:
      return ('Оплачен', Colors.green.shade700);
    case OrderStatus.cancelled:
      return ('Отменён', Colors.red.shade700);
    case OrderStatus.expired:
      return ('Истёк', Colors.blueGrey);
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
        title: const Text('Отменить заказ?'),
        content: const Text('Билеты из этого заказа станут недействительными.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Нет')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true), child: const Text('Отменить заказ')),
        ],
      ),
    );
    if (ok == true) _run(() => api.cancelOrder(_order.id), 'Заказ отменён');
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    final theme = Theme.of(context);
    final (label, color) = orderStatusLabel(o.status);
    final free = o.totalAmount == 0;

    return Scaffold(
      appBar: AppBar(title: Text('Заказ №${o.id}')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(o.eventTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            if (o.status == OrderStatus.pending && o.expiresAt != null)
              Text('Билеты забронированы до ${formatDateTime(o.expiresAt!)}',
                  style: theme.textTheme.bodySmall),
            const Divider(height: 32),
            for (final i in o.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(child: Text('${i.ticketTypeName} × ${i.quantity}')),
                    Text(i.unitPrice == 0
                        ? 'Бесплатно'
                        : formatPrice(i.unitPrice * i.quantity)),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: Text('Итого', style: theme.textTheme.titleMedium)),
                Text(free ? '0 ₸' : formatPrice(o.totalAmount),
                    style: theme.textTheme.titleMedium),
              ],
            ),
            if (o.status == OrderStatus.pending) ...[
              const SizedBox(height: 24),
              if (!free)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    border: Border.all(color: Colors.amber.shade700),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'ДЕМО-ОПЛАТА: это симуляция для учебного проекта. '
                    'Реальные деньги не списываются.',
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run(() => api.payOrder(o.id),
                        free ? 'Регистрация подтверждена' : 'Оплата прошла (демо)'),
                child: Text(free ? 'Подтвердить регистрацию' : 'Оплатить (демо)'),
              ),
            ],
            if (o.status == OrderStatus.pending || o.status == OrderStatus.paid)
              TextButton(
                onPressed: _busy ? null : _cancel,
                child: const Text('Отменить заказ'),
              ),
            if (_tickets.isNotEmpty) ...[
              const Divider(height: 32),
              Text('Билеты', style: theme.textTheme.titleMedium),
              for (final t in _tickets)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.qr_code_2),
                  title: Text(t.ticketTypeName),
                  subtitle: Text(t.code),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => TicketScreen(ticket: t))),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
