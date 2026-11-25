import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/file_share.dart';

/// "Add to calendar" (SRS 4.11): web calendars or an .ics file, both made by
/// the server. For a cancelled event only the .ics file is offered, which
/// removes the entry from calendars that imported it.
class CalendarButton extends StatelessWidget {
  final int eventId;
  const CalendarButton({super.key, required this.eventId});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (_) => _CalendarSheet(eventId: eventId),
        ),
        icon: const Icon(Icons.edit_calendar_outlined),
        label: Text(tr('cal.add')),
      );
}

class _CalendarSheet extends StatefulWidget {
  final int eventId;
  const _CalendarSheet({required this.eventId});

  @override
  State<_CalendarSheet> createState() => _CalendarSheetState();
}

class _CalendarSheetState extends State<_CalendarSheet> {
  late Future<CalendarLinks> _links = api.getCalendarLinks(widget.eventId);
  bool _downloading = false;
  // Shown inside the sheet: a snack bar would be hidden behind it.
  String? _error;

  Future<void> _open(String url) async {
    var opened = false;
    final uri = Uri.tryParse(url);
    if (uri != null && uri.scheme == 'https') {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        // Reported below.
      }
    }
    if (!mounted) return;
    if (opened) {
      Navigator.pop(context);
    } else {
      setState(() => _error = tr('cal.openFailed'));
    }
  }

  Future<void> _download() async {
    setState(() {
      _downloading = true;
      _error = null;
    });
    try {
      final bytes = await api.getCalendarFile(widget.eventId);
      if (!mounted) return;
      await shareFile(
          context, bytes, 'event-${widget.eventId}.ics', 'text/calendar');
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = tr('cal.openFailed');
    }
    if (mounted) setState(() => _downloading = false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: FutureBuilder<CalendarLinks>(
          future: _links,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final links = snap.data;
            if (links == null) {
              final err = snap.error;
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  Text(err is ApiException ? err.message : tr('err.load'),
                      textAlign: TextAlign.center),
                  TextButton(
                    onPressed: () => setState(() =>
                        _links = api.getCalendarLinks(widget.eventId)),
                    child: Text(tr('retry')),
                  ),
                ]),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (links.cancelled)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(tr('cal.cancelled')),
                  )
                else
                  for (final (name, url) in [
                    ('Google Calendar', links.google),
                    ('Outlook', links.outlook),
                    ('Office 365', links.office365),
                  ])
                    if (url != null)
                      ListTile(
                        leading: const Icon(Icons.open_in_new),
                        title: Text(name),
                        onTap: () => _open(url),
                      ),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined),
                  title: Text(tr(
                      links.cancelled ? 'cal.icsCancelled' : 'cal.ics')),
                  enabled: !_downloading,
                  onTap: _download,
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
