import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/language_menu.dart';
import 'admin_users_screen.dart';
import 'event_selection_screen.dart';
import 'events_screen.dart';
import 'login_screen.dart';
import 'my_orders_screen.dart';
import 'my_tickets_screen.dart';
import 'organizer_events_screen.dart';
import 'profile_screen.dart';

class _Tab {
  final String id;
  final IconData icon;
  final String navLabel;
  final String title;
  final Widget page;
  const _Tab(this.id, this.icon, this.navLabel, this.title, this.page);
}

/// Main screen after login. Everyone gets the attendee tabs; organizers get
/// "My events", check-in staff get "Check-in", platform admins get "Users".
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _current = 'events';
  bool _isStaff = false;
  // Bumped when a tab is selected so its list is reloaded (e.g. new tickets).
  final _visits = <String, int>{};

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
      // Not staff (403) or offline: no check-in tab.
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

  Future<void> _openProfile() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
    if (!mounted) return;
    // The role may have changed (became an organizer).
    setState(() {});
    _checkStaff();
  }

  List<_Tab> _tabs() {
    final role = AuthService.user?.role;
    return [
      _Tab('events', Icons.event, tr('nav.events'), tr('nav.events'), const EventsScreen()),
      _Tab('tickets', Icons.confirmation_number, tr('nav.tickets'),
          tr('title.tickets'), const MyTicketsScreen()),
      _Tab('orders', Icons.receipt_long, tr('nav.orders'), tr('nav.orders'),
          const MyOrdersScreen()),
      if (role == 'ORGANIZER')
        _Tab('mine', Icons.campaign_outlined, tr('nav.myEvents'), tr('nav.myEvents'),
            const OrganizerEventsScreen()),
      if (_isStaff)
        _Tab('checkin', Icons.qr_code_scanner, tr('nav.checkin'), tr('title.checkin'),
            const EventSelectionScreen()),
      if (role == 'PLATFORM_ADMIN')
        _Tab('users', Icons.people_outline, tr('nav.users'), tr('title.users'),
            const AdminUsersScreen()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs();
    var index = tabs.indexWhere((t) => t.id == _current);
    if (index < 0) index = 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(tabs[index].title),
        actions: [
          const LanguageMenu(),
          PopupMenuButton<void>(
            icon: const Icon(Icons.account_circle),
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text(AuthService.user?.email ?? ''),
              ),
              PopupMenuItem(
                onTap: _openProfile,
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: Text(tr('menu.profile')),
                ),
              ),
              PopupMenuItem(
                onTap: _logout,
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout),
                  title: Text(tr('menu.logout')),
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: index,
        children: [
          for (final t in tabs)
            KeyedSubtree(
              key: ValueKey('${t.id}-${_visits[t.id] ?? 0}'),
              child: t.page,
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() {
          final id = tabs[i].id;
          if (id != _current) _visits[id] = (_visits[id] ?? 0) + 1;
          _current = id;
        }),
        destinations: [
          for (final t in tabs)
            NavigationDestination(icon: Icon(t.icon), label: t.navLabel),
        ],
      ),
    );
  }
}
