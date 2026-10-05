import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';
import 'scanner_screen.dart';

class EventSelectionScreen extends StatefulWidget {
  const EventSelectionScreen({super.key});

  @override
  State<EventSelectionScreen> createState() => _EventSelectionScreenState();
}

class _EventSelectionScreenState extends State<EventSelectionScreen> {
  late Future<List<EventInfo>> _future;

  @override
  void initState() {
    super.initState();
    _future = api.getAssignedEvents();
  }

  void _reload() => setState(() => _future = api.getAssignedEvents());

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('BiletFlow — Выбор события'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Выйти',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: FutureBuilder<List<EventInfo>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            final err = snap.error;
            if (err is ApiException && err.unauthorized) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _logout());
            }
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off, size: 48),
                    const SizedBox(height: 12),
                    Text(err is ApiException
                        ? err.message
                        : 'Не удалось загрузить события'),
                    const SizedBox(height: 12),
                    OutlinedButton(
                        onPressed: _reload, child: const Text('Повторить')),
                  ],
                ),
              ),
            );
          }
          final events = snap.data ?? [];
          if (events.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Вам пока не назначено ни одного мероприятия.\n'
                  'Обратитесь к организатору.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _future;
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: events.length,
              itemBuilder: (context, i) {
                final e = events[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.event_available,
                        color: Colors.deepPurple),
                    title: Text(e.title),
                    subtitle: Text(e.subtitle),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ScannerScreen(event: e)),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
