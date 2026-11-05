import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/async_list.dart';
import 'order_screen.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  final _list = GlobalKey<AsyncListState<Order>>();

  @override
  Widget build(BuildContext context) {
    return AsyncList<Order>(
      key: _list,
      load: api.getMyOrders,
      emptyText: tr('orders.empty'),
      itemBuilder: (context, o) => _OrderCard(
        order: o,
        onTap: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => OrderScreen(order: o)));
          _list.currentState?.reload();
        },
      ),
    );
  }
}

IconData _statusIcon(OrderStatus s) => switch (s) {
      OrderStatus.pending => Icons.hourglass_top,
      OrderStatus.paid => Icons.check_circle,
      OrderStatus.cancelled => Icons.cancel,
      OrderStatus.expired => Icons.timer_off,
    };

class _OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;
  const _OrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final o = order;
    final (label, color) = orderStatusLabel(o.status);
    final free = o.totalAmount == 0;
    final count = o.items.fold<int>(0, (s, i) => s + i.quantity);

    return Material(
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_statusIcon(o.status), color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.eventTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        tr('orders.number', {'id': o.id}),
                        if (count > 0) tr('orders.ticketsN', {'n': count}),
                      ].join(' • '),
                      style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    if (o.createdAt != null)
                      Text(formatDateTime(o.createdAt!),
                          style: t.bodySmall?.copyWith(color: cs.outline)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    free ? tr('free') : formatPrice(o.totalAmount),
                    style: t.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: free ? const Color(0xFF16A34A) : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  StatusChip(label, color),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
