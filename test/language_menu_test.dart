import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/widgets/language_menu.dart';

void main() {
  testWidgets('App bar follows each language selected from the popup', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(appBar: AppBar(actions: const [LanguageMenu()])),
      ),
    );
    expect(find.text('RU'), findsOneWidget);
    for (final choice in [
      ('Қазақша', 'KZ'),
      ('English', 'EN'),
      ('Русский', 'RU'),
    ]) {
      await tester.tap(find.byIcon(Icons.language));
      await tester.pumpAndSettle();
      await tester.tap(find.text(choice.$1));
      await tester.pumpAndSettle();
      expect(find.text(choice.$2), findsOneWidget);
    }
  });
}
