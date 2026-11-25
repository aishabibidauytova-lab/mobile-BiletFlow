import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/l10n/l10n.dart';
import 'package:mobile/models/models.dart';
import 'package:mobile/screens/admin_tools_screen.dart';
import 'package:mobile/screens/organizer_events_screen.dart';
import 'package:mobile/screens/support_screens.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_service.dart';

void main() {
  final requests = <Uri>[];
  setUpAll(() {
    // Initialize the application's HTTP client in the mock client's zone.
    http.runWithClient(
      () => api.token = 'test',
      () => MockClient((request) async {
        requests.add(request.url);
        const item = {'id': 42, 'subject': 'Ticket help', 'requesterId': 9};
        if (request.url.path == '/api/support/cases' &&
            request.url.queryParameters['escalated'] == null) {
          return http.Response(
            jsonEncode({
              'content': [item],
            }),
            200,
          );
        }
        if (request.url.path == '/api/support/cases/42') {
          return http.Response(
            jsonEncode({'supportCase': item, 'messages': []}),
            200,
          );
        }
        return http.Response('{"content":[],"last":true}', 200);
      }),
    );
  });
  testWidgets('Organizer opens Support after Sales and filters requests', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    AuthService.user = const AppUser(
      id: 3,
      email: 'test@example.org',
      role: 'ORGANIZER',
    );
    addTearDown(() {
      AuthService.user = null;
      api.token = null;
    });

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: OrganizerEventsScreen())),
    );
    await tester.pumpAndSettle();
    final tab = find.widgetWithText(ChoiceChip, tr('support.title'));
    expect(tab.hitTestable(), findsOneWidget);
    await tester.tap(tab);
    await tester.pumpAndSettle();

    expect(find.byType(SupportListScreen), findsOneWidget);
    expect(find.text(tr('support.new')), findsOneWidget);
    expect(requests.last.path, '/api/support/cases');
    expect(requests.last.queryParameters.containsKey('escalated'), isFalse);

    final filter = find.widgetWithText(ChoiceChip, tr('support.status.OPEN'));
    await tester.tap(filter);
    await tester.pumpAndSettle();
    expect(requests.last.queryParameters['status'], 'OPEN');
    await tester.tap(find.textContaining('Ticket help'));
    await tester.pumpAndSettle();
    expect(find.byType(SupportCaseScreen), findsOneWidget);
    expect(find.byTooltip(tr('support.send')), findsOneWidget);
  });
  testWidgets('Platform administration opens only escalated cases', (
    tester,
  ) async {
    requests.clear();
    await tester.pumpWidget(const MaterialApp(home: AdminToolsScreen()));
    await tester.pumpAndSettle();
    final tab = find.widgetWithText(Tab, tr('adm.escalated'));
    await tester.ensureVisible(tab);
    await tester.tap(tab);
    await tester.pumpAndSettle();
    expect(find.byType(SupportListScreen), findsOneWidget);
    final request = requests.lastWhere((u) => u.path == '/api/support/cases');
    expect(request.queryParameters['escalated'], 'true');
    expect(find.text(tr('support.new')), findsNothing);
  });
}
