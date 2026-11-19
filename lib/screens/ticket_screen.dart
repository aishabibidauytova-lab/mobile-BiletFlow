import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/app_background.dart';
import '../widgets/event_poster.dart';
import 'support_screens.dart';

/// Dashed tear line with half-circle notches on both sides.
class _TearLine extends StatelessWidget {
  final Color background;
  const _TearLine({required this.background});

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return Container(
      height: 24,
      color: surface,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: LayoutBuilder(builder: (context, box) {
                final n = (box.maxWidth / 10).floor();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (var i = 0; i < n; i++)
                      Container(
                        width: 5,
                        height: 1.5,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                  ],
                );
              }),
            ),
          ),
          Positioned(
            left: -12,
            child: CircleAvatar(radius: 12, backgroundColor: background),
          ),
          Positioned(
            right: -12,
            child: CircleAvatar(radius: 12, backgroundColor: background),
          ),
        ],
      ),
    );
  }
}

(String, Color) ticketStatusLabel(TicketStatus s) {
  switch (s) {
    case TicketStatus.valid:
      return (tr('ticket.valid'), Colors.green.shade700);
    case TicketStatus.used:
      return (tr('ticket.used'), Colors.blueGrey);
    case TicketStatus.cancelled:
      return (tr('ticket.cancelled'), Colors.red.shade700);
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
    final cs = theme.colorScheme;
    final valid = t.status == TicketStatus.valid;
    final colors = valid
        ? posterPalette(t.eventId)
        : [Colors.blueGrey.shade400, Colors.blueGrey.shade600];

    return Scaffold(
      appBar: AppBar(title: Text(tr('ticket.title'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: colors.first.withValues(alpha: 0.25),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Column(
                    children: [
                      // Header: event + ticket type + status.
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: colors,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.ticketTypeName.toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1)),
                            const SizedBox(height: 6),
                            Text(t.eventTitle,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    height: 1.15)),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    switch (t.status) {
                                      TicketStatus.valid => Icons.verified,
                                      TicketStatus.used => Icons.task_alt,
                                      TicketStatus.cancelled => Icons.block,
                                    },
                                    size: 16,
                                    color: color,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(label,
                                      style: TextStyle(
                                          color: color,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Tear line with notches.
                      const _TearLine(background: kBackdropColor),
                      // Body: QR + code.
                      Container(
                        width: double.infinity,
                        color: cs.surface,
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        child: Column(
                          children: [
                            Container(
                              // White background keeps the code scannable.
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: cs.outlineVariant),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Opacity(
                                opacity: valid ? 1 : 0.2,
                                child: Image.network(
                                  api.ticketQrUri(t.id).toString(),
                                  headers: api.authHeaders,
                                  width: 240,
                                  height: 240,
                                  fit: BoxFit.contain,
                                  loadingBuilder: (c, child, progress) => progress == null
                                      ? child
                                      : const SizedBox(
                                          width: 240,
                                          height: 240,
                                          child: Center(
                                              child: CircularProgressIndicator())),
                                  errorBuilder: (c, e, s) => SizedBox(
                                    width: 240,
                                    height: 240,
                                    child: Center(
                                      child: Text(tr('ticket.qrFailed'),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(color: Colors.black54)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: SelectableText(t.code,
                                        style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                  IconButton(
                                    tooltip: tr('ticket.copy'),
                                    icon: const Icon(Icons.copy, size: 18),
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: t.code));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                              content: Text(tr('ticket.copied'))));
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      switch (t.status) {
                        TicketStatus.valid =>
                          tr('ticket.hintValid'),
                        TicketStatus.used => t.usedAt != null
                            ? tr('ticket.hintUsedAt', {'date': formatDateTime(t.usedAt!)})
                            : tr('ticket.hintUsed'),
                        TicketStatus.cancelled => tr('ticket.hintCancelled'),
                      },
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (t.status != TicketStatus.cancelled) _PdfButton(ticket: t),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NewSupportCaseScreen(
                      eventId: t.eventId,
                      orderId: t.orderId,
                      ticketId: t.id,
                      context: '${t.eventTitle} • ${t.ticketTypeName} • №${t.id}',
                    ),
                  ),
                ),
                icon: const Icon(Icons.support_agent),
                label: Text(tr('support.contact')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Downloads the server-generated, print-ready PDF (SRS 4.7) and opens the
/// system share / print dialog (save to Files, print, send).
class _PdfButton extends StatefulWidget {
  final Ticket ticket;
  const _PdfButton({required this.ticket});

  @override
  State<_PdfButton> createState() => _PdfButtonState();
}

class _PdfButtonState extends State<_PdfButton> {
  bool _loading = false;

  Future<void> _download() async {
    setState(() => _loading = true);
    try {
      final bytes = await api.getTicketPdf(widget.ticket.id);
      await Printing.sharePdf(
          bytes: Uint8List.fromList(bytes),
          filename: 'biletflow-ticket-${widget.ticket.id}.pdf');
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr('ticket.pdfFailed'))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      onPressed: _loading ? null : _download,
      icon: _loading
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.picture_as_pdf_outlined),
      label: Text(tr('ticket.pdf')),
    );
  }
}
