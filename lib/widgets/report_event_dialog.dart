import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../services/api_service.dart';

/// Lets an attendee report an event to the platform admins (SRS 4.12).
Future<void> showReportEventDialog(BuildContext context, int eventId) async {
  final sent = await showDialog<bool>(
    context: context,
    builder: (_) => _ReportDialog(eventId: eventId),
  );
  if (sent == true && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(tr('report.sent'))));
  }
}

class _ReportDialog extends StatefulWidget {
  final int eventId;
  const _ReportDialog({required this.eventId});

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _message = TextEditingController();
  String _reason = reportReasons.first;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await api.reportEvent(widget.eventId, _reason, _message.text);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('report.title')),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _reason,
                isExpanded: true,
                decoration: InputDecoration(
                    labelText: tr('adm.reason'),
                    border: const OutlineInputBorder()),
                items: [
                  for (final r in reportReasons)
                    DropdownMenuItem(
                        value: r, child: Text(tr('report.reason.$r'))),
                ],
                onChanged: (v) => _reason = v ?? _reason,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _message,
                maxLines: 4,
                maxLength: 1000,
                decoration: InputDecoration(
                    labelText: tr('report.message'),
                    border: const OutlineInputBorder()),
              ),
              if (_error != null)
                Text(_error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(tr('cancel'))),
        FilledButton(
            onPressed: _sending ? null : _send, child: Text(tr('report.send'))),
      ],
    );
  }
}
