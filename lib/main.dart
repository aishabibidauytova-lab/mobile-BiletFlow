import 'package:flutter/material.dart';

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
      title: 'BiletFlow Check-In',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const AuthGate(),
    );
  }
}

/// Shows the login screen or the event list depending on a saved session.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
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
    );
  }
}
