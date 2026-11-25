import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../services/api_service.dart';

/// Checkout step before the order is created: attendee name, promo code and a
/// server-calculated price preview (SRS 4.6, 4.14). Returns the created order.
Future<Order?> showCheckoutSheet(
  BuildContext context, {
  required EventInfo event,
  required Map<int, int> quantities,
  required List<TicketType> types,
  List<SelectedSeat> seats = const [],
  String? promoCode,
}) =>
    showModalBottomSheet<Order>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CheckoutSheet(
          event: event,
          quantities: quantities,
          types: types,
          seats: seats,
          promoCode: promoCode),
    );

class _CheckoutSheet extends StatefulWidget {
  final EventInfo event;
  final Map<int, int> quantities;
  final List<TicketType> types;
  final List<SelectedSeat> seats;
  final String? promoCode;
  const _CheckoutSheet(
      {required this.event,
      required this.quantities,
      required this.types,
      this.seats = const [],
      this.promoCode});

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  List<int> get _seatIds => [for (final s in widget.seats) s.id];

  final _name = TextEditingController();
  final _promo = TextEditingController();
  OrderQuote? _quote;
  String? _appliedCode;
  String? _promoError;
  bool _quoting = false;
  bool _ordering = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final code = widget.promoCode;
    if (code == null) return _loadQuote();
    _promo.text = code;
    await _loadQuote(code);
    // The code may not fit the chosen tickets: still show the regular price.
    if (mounted && _quote == null) {
      final error = _promoError;
      await _loadQuote();
      if (mounted) setState(() => _promoError = error);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _promo.dispose();
    super.dispose();
  }

  Future<void> _loadQuote([String? code]) async {
    setState(() {
      _quoting = true;
      _promoError = null;
    });
    try {
      final q = await api.quoteOrder(widget.event.id, widget.quantities,
          seatIds: _seatIds, promoCode: code);
      if (!mounted) return;
      setState(() {
        _quote = q;
        _appliedCode = code;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      // Invalid / expired / exhausted code: keep the previous quote.
      setState(() => code == null ? _error = e.message : _promoError = e.message);
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  void _applyPromo() {
    final code = _promo.text.trim();
    if (code.isEmpty) return;
    FocusScope.of(context).unfocus();
    _loadQuote(code);
  }

  void _removePromo() {
    _promo.clear();
    _loadQuote();
  }

  Future<void> _confirm() async {
    setState(() {
      _ordering = true;
      _error = null;
    });
    try {
      final order = await api.createOrder(widget.event.id, widget.quantities,
          seatIds: _seatIds,
          attendeeName: _name.text.trim(),
          promoCode: _appliedCode);
      if (mounted) Navigator.pop(context, order);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _ordering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final q = _quote;
    final free = q != null && q.total == 0;
    final byId = {for (final tt in widget.types) tt.id: tt};

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('checkout.title'),
                style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            Text(widget.event.title,
                style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            for (final e in widget.quantities.entries)
              if (e.value > 0 && byId[e.key] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text('${byId[e.key]!.name} × ${e.value}')),
                      Text(formatPrice(byId[e.key]!.price * e.value)),
                    ],
                  ),
                ),
            for (final s in widget.seats)
              if (byId[s.ticketTypeId] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(
                              '${byId[s.ticketTypeId]!.name} · ${s.label}')),
                      Text(formatPrice(byId[s.ticketTypeId]!.price)),
                    ],
                  ),
                ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: tr('checkout.attendeeName'),
                helperText: tr('checkout.attendeeHint'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _promo,
                    enabled: _appliedCode == null,
                    textCapitalization: TextCapitalization.characters,
                    onSubmitted: (_) => _applyPromo(),
                    decoration: InputDecoration(
                      labelText: tr('checkout.promo'),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.local_offer_outlined),
                      errorText: _promoError,
                      errorMaxLines: 3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _appliedCode == null
                      ? FilledButton.tonal(
                          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                          onPressed: _quoting ? null : _applyPromo,
                          child: Text(tr('checkout.apply')),
                        )
                      : OutlinedButton(
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                          onPressed: _quoting ? null : _removePromo,
                          child: Text(tr('checkout.removePromo')),
                        ),
                ),
              ],
            ),
            const Divider(height: 28),
            if (q == null)
              Center(
                child: _quoting
                    ? const CircularProgressIndicator()
                    : Text(_error ?? tr('err.load')),
              )
            else ...[
              _Line(tr('checkout.subtotal'), formatPrice(q.subtotal)),
              if (q.discount > 0)
                _Line(
                  q.promoCode == null
                      ? tr('checkout.discount')
                      : tr('checkout.discountCode', {'code': q.promoCode}),
                  '−${formatPrice(q.discount)}',
                  color: Colors.green.shade700,
                ),
              const SizedBox(height: 4),
              _Line(tr('order.total'), q.total == 0 ? '0 ₸' : formatPrice(q.total),
                  bold: true),
            ],
            if (_error != null && q != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: cs.error)),
            ],
            if ((widget.event.refundPolicy ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(tr('policy.title'), style: t.labelLarge),
              Text(widget.event.refundPolicy!.trim(),
                  style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
            const SizedBox(height: 18),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: _ordering || _quoting || q == null ? null : _confirm,
              child: _ordering
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(free ? tr('detail.register') : tr('checkout.placeOrder')),
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;
  const _Line(this.label, this.value, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final style = (bold ? t.titleMedium : t.bodyLarge)
        ?.copyWith(fontWeight: bold ? FontWeight.w800 : null, color: color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
