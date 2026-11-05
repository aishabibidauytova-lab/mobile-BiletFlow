import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/l10n.dart';
import 'widgets/app_background.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await l10n.load();
  api.onUnauthorized = () async {
    await AuthService.logout();
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  };
  runApp(const BiletFlowApp());
}

ThemeData _buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF5B3FD0),
    surface: Colors.white,
  );
  const radius = 14.0;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    // Transparent so the decorative AppBackground shows through.
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: Color(0xFF1C1B1F),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.88),
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ),
    searchBarTheme: SearchBarThemeData(
      backgroundColor: const WidgetStatePropertyAll(Colors.white),
      side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
      constraints: const BoxConstraints(minHeight: 52),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      side: BorderSide(color: scheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
    ),
  );
}

class BiletFlowApp extends StatelessWidget {
  const BiletFlowApp({super.key});
  @override
  Widget build(BuildContext context) {
    // Rebuild the whole app when the language changes.
    return ListenableBuilder(
      listenable: l10n,
      builder: (context, _) => MaterialApp(
        navigatorKey: navigatorKey,
        title: 'BiletFlow',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        locale: Locale(l10n.lang.code),
        supportedLocales: [for (final l in AppLang.values) Locale(l.code)],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // A new key per language rebuilds every screen with the new strings.
        builder: (context, child) =>
            KeyedSubtree(
          key: ValueKey(l10n.lang),
          child: AppBackground(child: child!),
        ),
        home: const AuthGate(),
      ),
    );
  }
}

/// Shows the login screen or the home screen depending on a saved session.
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
        return snap.data == true ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}
