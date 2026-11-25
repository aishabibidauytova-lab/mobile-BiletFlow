import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../services/api_service.dart';

/// One-line check-in / absent counts of an event for the organizer dashboard.
class AttendanceLine extends StatefulWidget {
  final int eventId;
  const AttendanceLine({super.key, required this.eventId});

  @override
  State<AttendanceLine> createState() => _AttendanceLineState();
}

class _AttendanceLineState extends State<AttendanceLine> {
  late final Future<Attendance> _future = api.getAttendance(widget.eventId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Attendance>(
      future: _future,
      builder: (context, snap) {
        final a = snap.data;
        final text = a != null
            ? tr('att.line', {
                'in': a.checkedIn,
                'all': a.ticketHolders,
                'absent': a.absent,
              })
            : snap.hasError
                ? '${tr('att.title')}: —'
                : '${tr('att.title')}: …';
        return Row(
          children: [
            const Icon(Icons.how_to_reg_outlined, size: 18),
            const SizedBox(width: 6),
            Expanded(child: Text(text)),
          ],
        );
      },
    );
  }
}
