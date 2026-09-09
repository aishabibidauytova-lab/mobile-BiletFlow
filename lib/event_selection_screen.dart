import 'package:flutter/material.dart';
import 'scanner_screen.dart';

class EventSelectionScreen extends StatelessWidget {
  const EventSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BiletFlow — Выбор события'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Выберите мероприятие',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.event_available,
                    color: Colors.deepPurple,
                  ),
                  title: const Text('Тестовое мероприятие BiletFlow'),
                  subtitle: const Text('Астана • 2026'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ScannerScreen(
                          eventTitle: 'Тестовое мероприятие BiletFlow',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
