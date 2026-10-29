import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/async_list.dart';

(String, Color) ticketStatusLabel(TicketStatus s) {
  switch (s) {
    case TicketStatus.valid:
      return ('Действителен', Colors.green.shade700);
    case TicketStatus.used:
      return ('Использован', Colors.blueGrey);
    case TicketStatus.cancelled:
      return ('Отменён', Colors.red.shade700);
  }
}

/// A single ticket with its server-generated QR code, shown at the entrance.
class TicketScreen extends StatelessWidget {
  final Ticket ticket;
  const TicketScreen({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    final t = ticket;
    final (label, color) = ticketStatusLabel(t.status);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Билет')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(t.eventTitle,
              textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(t.ticketTypeName,
              textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Center(child: StatusChip(label, color)),
          const SizedBox(height: 24),
          Center(
            child: Container(
              // White background keeps the code scannable in dark mode too.
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Opacity(
                opacity: t.status == TicketStatus.valid ? 1 : 0.25,
                child: Image.network(
                  api.ticketQrUri(t.id).toString(),
                  headers: api.authHeaders,
                  width: 260,
                  height: 260,
                  fit: BoxFit.contain,
                  loadingBuilder: (c, child, progress) => progress == null
                      ? child
                      : const SizedBox(
                          width: 260,
                          height: 260,
                          child: Center(child: CircularProgressIndicator())),
                  errorBuilder: (c, e, s) => const SizedBox(
                    width: 260,
                    height: 260,
                    child: Center(
                      child: Text('Не удалось загрузить QR-код.\nПроверьте интернет.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SelectableText(t.code,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 16)),
          const SizedBox(height: 16),
          Text(
            switch (t.status) {
              TicketStatus.valid =>
                'Покажите этот QR-код на входе. Не передавайте его другим: '
                    'пройти по билету можно только один раз.',
              TicketStatus.used => t.usedAt != null
                  ? 'Вход по билету выполнен ${formatDateTime(t.usedAt!)}.'
                  : 'Вход по билету уже выполнен.',
              TicketStatus.cancelled => 'Билет отменён и не действует.',
            },
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
