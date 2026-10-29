import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
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
    return Scaffold(
      appBar: AppBar(title: Text(e.title, overflow: TextOverflow.ellipsis)),
      body: FutureBuilder<List<TicketType>>(
        future: _future,
        builder: (context, snap) {
          final types = snap.data ?? const <TicketType>[];
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(e.title, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    if (e.startTime != null)
                      _InfoRow(Icons.schedule, [
                        formatDateTime(e.startTime!),
                        if (e.endTime != null) formatTime(e.endTime!),
                      ].join(' – ')),
                    if (e.venue != null)
                      _InfoRow(Icons.place,
                          '${e.venue!.name}\n${e.venue!.address}'),
                    if (e.category.isNotEmpty) _InfoRow(Icons.label, e.category),
                    if (e.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(e.description),
                    ],
                    const SizedBox(height: 24),
                    Text('Билеты', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (_registrationClosed)
                      Text(
                        e.isCancelled
                            ? 'Мероприятие отменено.'
                            : 'Регистрация закрыта.',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    if (snap.connectionState != ConnectionState.done)
                      const Center(child: CircularProgressIndicator())
                    else if (snap.hasError)
                      Text(snap.error is ApiException
                          ? (snap.error as ApiException).message
                          : 'Не удалось загрузить билеты')
                    else if (types.isEmpty)
                      const Text('Билеты пока не продаются.')
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
              if (_count > 0)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Итого: ${_total(types) == 0 ? '0 ₸' : formatPrice(_total(types))}',
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        FilledButton(
                          onPressed: _ordering ? null : _order,
                          child: _ordering
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : Text(_total(types) == 0
                                  ? 'Зарегистрироваться'
                                  : 'Оформить заказ'),
                        ),
                      ],
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
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
      note = 'Распродано';
    } else if (!type.onSale) {
      note = 'Продажи закрыты';
    } else {
      note = 'Осталось: ${type.available}';
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(type.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(formatPrice(type.price)),
                  if (type.description.isNotEmpty)
                    Text(type.description,
                        style: Theme.of(context).textTheme.bodySmall),
                  Text(note, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Меньше',
              onPressed: enabled && quantity > 0 ? () => onChanged(quantity - 1) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text('$quantity', style: const TextStyle(fontSize: 16)),
            IconButton(
              tooltip: 'Больше',
              onPressed: enabled && quantity < max ? () => onChanged(quantity + 1) : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }
}
