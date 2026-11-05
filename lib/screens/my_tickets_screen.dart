import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/async_list.dart';
import '../widgets/event_poster.dart';
import 'ticket_screen.dart';

class MyTicketsScreen extends StatelessWidget {
  const MyTicketsScreen({super.key});

  Future<List<Ticket>> _load() async {
    final tickets = await api.getMyTickets();
    // Active tickets first, newest first within each group.
    int rank(Ticket t) => t.status == TicketStatus.valid ? 0 : 1;
    return [...tickets]..sort((a, b) {
        final r = rank(a).compareTo(rank(b));
        return r != 0 ? r : b.id.compareTo(a.id);
      });
  }

  @override
  Widget build(BuildContext context) {
    return AsyncList<Ticket>(
      load: _load,
      emptyText: tr('tickets.empty'),
      itemBuilder: (context, t) => _TicketStub(
        ticket: t,
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => TicketScreen(ticket: t))),
      ),
    );
  }
}

/// Ticket-shaped list row: colour block on the left, perforation, details.
class _TicketStub extends StatelessWidget {
  final Ticket ticket;
  final VoidCallback onTap;
  const _TicketStub({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final (label, color) = ticketStatusLabel(ticket.status);
    final active = ticket.status == TicketStatus.valid;
    final colors = posterPalette(ticket.eventId);

    return Material(
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 84,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: active
                        ? colors
                        : [Colors.blueGrey.shade300, Colors.blueGrey.shade400],
                  ),
                ),
                child: const Icon(Icons.confirmation_number_outlined,
                    color: Colors.white, size: 34),
              ),
              const _Perforation(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(ticket.eventTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(ticket.ticketTypeName,
                          style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          StatusChip(label, color),
                          const Spacer(),
                          Text('№${ticket.id}',
                              style: t.labelMedium?.copyWith(color: cs.outline)),
                          const SizedBox(width: 4),
                          Icon(Icons.qr_code_2, size: 20, color: cs.primary),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) {
    // CustomPaint (not LayoutBuilder) so it works inside IntrinsicHeight.
    return CustomPaint(
      size: const Size(1, 0),
      painter: _DashPainter(Theme.of(context).colorScheme.outlineVariant),
    );
  }
}

class _DashPainter extends CustomPainter {
  final Color color;
  _DashPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var y = 6.0; y < size.height - 6; y += 8) {
      canvas.drawLine(Offset(0.5, y), Offset(0.5, y + 4), p);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}
