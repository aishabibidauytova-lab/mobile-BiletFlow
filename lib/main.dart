import 'package:flutter/material.dart';
import 'event_selection_screen.dart';

import 'screens/event_selection_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BiletFlowApp());
}

class BiletFlowApp extends StatelessWidget {
  const BiletFlowApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
<<<<<<< HEAD
      title: 'BiletFlow Admin',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LoginScreen(),
=======
      title: 'BiletFlow Check-In',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const AuthGate(),
>>>>>>> a4b8aa6 (Fix build and update configuration)
    );
  }
}

/// Shows the login screen or the event list depending on a saved session.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    return Scaffold(
      appBar: AppBar(title: const Text('BiletFlow Check-In')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const TextField(
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Пароль',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EventSelectionScreen(),
                  ),
                );
              },
              child: const Text('Войти'),
            ),
          ],
        ),
      ),
=======
    return FutureBuilder<bool>(
      future: AuthService.restore(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snap.data == true
            ? const EventSelectionScreen()
            : const LoginScreen();
      },
>>>>>>> a4b8aa6 (Fix build and update configuration)
    );
  }
}
