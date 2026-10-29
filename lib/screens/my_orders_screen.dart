import 'package:flutter/material.dart';

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
      emptyText: 'Заказов пока нет.',
      itemBuilder: (context, o) {
        final (label, color) = orderStatusLabel(o.status);
        return Card(
          child: ListTile(
            title: Text(o.eventTitle),
            subtitle: Text([
              'Заказ №${o.id}',
              if (o.createdAt != null) formatDateTime(o.createdAt!),
              o.totalAmount == 0 ? 'Бесплатно' : formatPrice(o.totalAmount),
            ].join(' • ')),
            trailing: StatusChip(label, color),
            onTap: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => OrderScreen(order: o)));
              _list.currentState?.reload();
            },
          ),
        );
      },
    );
  }
}
