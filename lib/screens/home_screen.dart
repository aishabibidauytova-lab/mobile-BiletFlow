import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'event_selection_screen.dart';
import 'events_screen.dart';
import 'login_screen.dart';
import 'my_orders_screen.dart';
import 'my_tickets_screen.dart';

/// Main screen after login. Every user gets the attendee tabs; users assigned
/// as check-in staff to at least one event also get the "Проверка" tab.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  bool _isStaff = false;
  // Bumped when a tab is selected so its list is reloaded (e.g. new tickets).
  final _visits = [0, 0, 0, 0];

  @override
  void initState() {
    super.initState();
    _checkStaff();
  }

  Future<void> _checkStaff() async {
    try {
      final events = await api.getAssignedEvents();
      if (mounted) setState(() => _isStaff = events.isNotEmpty);
    } catch (_) {
      // Not staff (403) or offline: attendee tabs only.
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const EventsScreen(),
      const MyTicketsScreen(),
      const MyOrdersScreen(),
      if (_isStaff) const EventSelectionScreen(),
    ];
    const titles = ['Афиша', 'Мои билеты', 'Заказы', 'Проверка билетов'];
    final index = _index < pages.length ? _index : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[index]),
        actions: [
          PopupMenuButton<void>(
            icon: const Icon(Icons.account_circle),
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text(AuthService.user?.email ?? ''),
              ),
              PopupMenuItem(onTap: _logout, child: const Text('Выйти')),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: index,
        children: [
          for (var i = 0; i < pages.length; i++)
            KeyedSubtree(key: ValueKey('$i-${_visits[i]}'), child: pages[i]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() {
          if (i != _index) _visits[i]++;
          _index = i;
        }),
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.event), label: 'Афиша'),
          const NavigationDestination(
              icon: Icon(Icons.confirmation_number), label: 'Билеты'),
          const NavigationDestination(
              icon: Icon(Icons.receipt_long), label: 'Заказы'),
          if (_isStaff)
            const NavigationDestination(
                icon: Icon(Icons.qr_code_scanner), label: 'Проверка'),
        ],
      ),
    );
  }
}
