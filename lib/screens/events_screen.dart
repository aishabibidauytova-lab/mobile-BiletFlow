import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/async_list.dart';
import 'event_detail_screen.dart';

/// Public event catalog for attendees.
class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  Future<List<EventInfo>> _load() async {
    final events = await api.getEvents();
    return events.where((e) => e.status == 'PUBLISHED').toList();
  }

  @override
  Widget build(BuildContext context) {
    return AsyncList<EventInfo>(
      load: _load,
      emptyText: 'Сейчас нет доступных мероприятий.',
      itemBuilder: (context, e) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text([
              e.subtitle,
              if (e.category.isNotEmpty) e.category,
            ].join('\n')),
          ),
          isThreeLine: e.category.isNotEmpty,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EventDetailScreen(event: e)),
          ),
        ),
      ),
    );
  }
}
