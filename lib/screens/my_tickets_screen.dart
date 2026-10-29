import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/async_list.dart';
import 'ticket_screen.dart';

class MyTicketsScreen extends StatelessWidget {
  const MyTicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AsyncList<Ticket>(
      load: api.getMyTickets,
      emptyText: 'У вас пока нет билетов.\nВыберите мероприятие в «Афише».',
      itemBuilder: (context, t) {
        final (label, color) = ticketStatusLabel(t.status);
        return Card(
          child: ListTile(
            leading: const Icon(Icons.confirmation_number),
            title: Text(t.eventTitle),
            subtitle: Text(t.ticketTypeName),
            trailing: StatusChip(label, color),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => TicketScreen(ticket: t))),
          ),
        );
      },
    );
  }
}
