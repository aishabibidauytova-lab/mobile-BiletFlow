import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/async_list.dart';
import 'scanner_screen.dart';

/// Events the signed-in user is assigned to as check-in staff.
class EventSelectionScreen extends StatelessWidget {
  const EventSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AsyncList<EventInfo>(
      load: api.getAssignedEvents,
      emptyText: 'Вам пока не назначено ни одного мероприятия.\n'
          'Обратитесь к организатору.',
      itemBuilder: (context, e) => Card(
        child: ListTile(
          leading: const Icon(Icons.qr_code_scanner, color: Colors.deepPurple),
          title: Text(e.title),
          subtitle: Text(e.subtitle),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ScannerScreen(event: e)),
          ),
        ),
      ),
    );
  }
}
