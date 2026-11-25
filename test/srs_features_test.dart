import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/l10n/l10n.dart';
import 'package:mobile/l10n/l10n_srs.dart';
import 'package:mobile/models/models.dart';
import 'package:mobile/screens/admin_tools_screen.dart';
import 'package:mobile/screens/event_detail_screen.dart';
import 'package:mobile/screens/event_history_screen.dart';
import 'package:mobile/screens/event_sales_screen.dart';
import 'package:mobile/screens/organizer_events_screen.dart';
import 'package:mobile/screens/ticket_screen.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/campaign_link.dart';

const _event = {
  'id': 5,
  'title': 'Jazz Night',
  'category': 'Music',
  'startTime': '2030-05-01T19:00:00',
  'status': 'DRAFT',
  'phase': 'UPCOMING',
  'refundPolicy': 'Refunds up to 3 days before the show',
  'venue': {'id': 1, 'name': 'Blue Hall', 'address': 'Abay 1'},
};

Object _page(List<Object> items, {bool last = true}) =>
    {'content': items, 'last': last};

/// Canned answers for the endpoints used by the new screens.
Object _answer(http.Request r) {
  final path = r.url.path.replaceFirst('/api', '');
  return switch (path) {
    '/events/5' => _event,
    '/events/5/publish' => {..._event, 'status': 'PUBLISHED'},
    '/events/5/ticket-types' => [
        {'id': 11, 'name': 'Standard', 'price': 1000, 'available': 5},
      ],
    '/events/organizer/3' || '/organizer/events' => _page([_event]),
    '/organizer/sales/events' => {
        'events': [
          {'eventId': 5, 'eventTitle': 'Jazz Night'},
        ],
        'totals': {},
      },
    '/organizer/events/5/sales' => {
        'eventId': 5,
        'ticketsSold': 9,
        'ticketTypes': [
          {'ticketTypeId': 11, 'name': 'Standard', 'quantity': 20, 'sold': 7},
          {'ticketTypeId': 12, 'name': 'Balcony', 'quantity': 10, 'sold': 2},
        ],
        'salesByDay': [
          {'date': '2026-11-01', 'ticketsSold': 4, 'revenue': 4000},
        ],
      },
    '/organizer/events/5/attendance' => {
        'ticketHolders': 8,
        'checkedIn': 6,
        'absent': 2,
      },
    '/organizer/events/5/history' => _page([
        {
          'timestamp': '2026-11-02T10:00:00',
          'actorName': 'Dana',
          'action': 'EVENT_PUBLISHED',
          'description': 'Published the event',
        },
      ], last: r.url.queryParameters['page'] == '1'),
    '/admin/settings' => {
        'activationFeeKzt': 5000,
        'processingFeePercent': 2.5,
      },
    '/admin/event-reports' => _page([
        {
          'id': 4,
          'eventId': 5,
          'eventTitle': 'Jazz Night',
          'reason': 'SPAM',
          'status': 'OPEN',
          'reporterEmail': 'a@example.org',
        },
      ]),
    '/admin/orders' => _page([
        {
          'id': 70,
          'eventTitle': 'Jazz Night',
          'status': 'PAID',
          'buyerEmail': 'buyer@example.org',
          'totalAmount': 1000,
        },
      ], last: false),
    '/admin/payments' || '/admin/refunds' => _page([
        {
          'reference': 'REF-1',
          'status': 'FAILED',
          'amount': 1000,
          'eventTitle': 'Jazz Night',
        },
      ]),
    _ => _page([]),
  };
}

void main() {
  final requests = <http.Request>[];

  setUpAll(() {
    http.runWithClient(
      () => api.token = 'test',
      () => MockClient((request) async {
        requests.add(request);
        return http.Response.bytes(
            utf8.encode(jsonEncode(_answer(request))), 200);
      }),
    );
  });
  setUp(requests.clear);

  Future<void> show(WidgetTester tester, Widget screen,
      {Size size = const Size(360, 780)}) async {
    // A narrow phone, so layout overflows fail the test.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  Iterable<http.Request> sent(String path) =>
      requests.where((r) => r.url.path == '/api$path');

  test('Only event links of this site are campaign links', () {
    final link = CampaignLink.parse(
        'https://biletflow.duckdns.org/events/12?promo=abc123')!;
    expect((link.eventId, link.promo), (12, 'abc123'));
    expect(CampaignLink.parse('/events/12')!.promo, isNull);
    for (final other in [
      'https://evil.example/events/12?promo=x',
      'https://biletflow.duckdns.org/orders/12',
      'https://biletflow.duckdns.org/events/abc',
      'ftp://biletflow.duckdns.org/events/12',
      '/',
      'TICKET-CODE-123',
    ]) {
      expect(CampaignLink.parse(other), isNull, reason: other);
    }
  });

  test('A link value that is not a token is retried as a promo code', () async {
    final keys = <String>[];
    final service = BiletFlowApi(client: MockClient((r) async {
      keys.add(r.url.queryParameters.keys.single);
      return keys.last == 'token'
          ? http.Response('{"message":"invalid"}', 400)
          : http.Response('{"code":"SALE","discountValue":10}', 200);
    }));
    expect((await service.previewPromo(5, 'SALE')).code, 'SALE');
    expect(keys, ['token', 'code']);
  });

  test('Every new string has all three languages', () {
    for (final e in srsStrings.entries) {
      expect(e.value.length, AppLang.values.length, reason: e.key);
      expect(e.value.every((s) => s.trim().isNotEmpty), isTrue, reason: e.key);
    }
    for (final action in historyActions) {
      expect(srsStrings, contains('hist.$action'));
    }
    for (final type in historyEntityTypes) {
      expect(srsStrings, contains('hist.entity.$type'));
    }
  });

  testWidgets('The ticket shows date, venue and attendee name', (tester) async {
    await show(
        tester,
        const TicketScreen(
          ticket: Ticket(
            id: 1,
            code: 'ABC',
            status: TicketStatus.cancelled, // no QR image to download
            orderId: 2,
            eventId: 5,
            eventTitle: 'Jazz Night',
            ticketTypeName: 'Standard',
            attendeeEmail: 'a@example.org',
            attendeeName: 'Aigerim',
          ),
        ));
    expect(find.text('01.05.2030 19:00'), findsOneWidget);
    expect(find.text('Blue Hall, Abay 1'), findsOneWidget);
    expect(find.text('Aigerim'), findsOneWidget);
  });

  testWidgets('A draft is previewed, then published', (tester) async {
    await show(tester,
        EventDetailScreen(event: EventInfo.fromJson(_event), preview: true));
    expect(find.text(tr('preview.banner')), findsOneWidget);
    expect(find.byTooltip(tr('report.action')), findsNothing);
    expect(sent('/events/5/publish'), isEmpty);
    await tester.tap(find.text(tr('preview.publish')));
    await tester.pumpAndSettle();
    expect(sent('/events/5/publish'), hasLength(1));
  });

  testWidgets('An attendee reports an event', (tester) async {
    await show(tester, EventDetailScreen(event: EventInfo.fromJson(_event)));
    await tester.tap(find.byTooltip(tr('report.action')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('report.send')));
    await tester.pumpAndSettle();
    expect(jsonDecode(sent('/events/5/reports').single.body),
        {'reason': 'FRAUD'});
  });

  testWidgets('Sales show attendance and filter by ticket type', (tester) async {
    await show(tester, const EventSalesScreen(eventId: 5, title: 'Jazz Night'));
    await tester.scrollUntilVisible(find.text(tr('att.absent')), 200,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('75%'), findsOneWidget);

    final dropdown = find.byType(DropdownButtonFormField<int?>);
    await tester.ensureVisible(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Balcony').last);
    await tester.pumpAndSettle();
    for (final path in ['sales', 'attendance']) {
      expect(sent('/organizer/events/5/$path').last.url.queryParameters,
          {'ticketTypeId': '12'});
    }
  });

  testWidgets('Organizer filters events by phase and sees attendance',
      (tester) async {
    AuthService.user =
        const AppUser(id: 3, email: 'o@example.org', role: 'ORGANIZER');
    addTearDown(() => AuthService.user = null);
    // Wider than a phone: the square test font makes the header very tall.
    await show(tester, const Scaffold(body: OrganizerEventsScreen()),
        size: const Size(480, 900));

    final completed =
        find.widgetWithText(ChoiceChip, tr('phase.COMPLETED'));
    await tester.scrollUntilVisible(completed, 100,
        scrollable: find
            .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.right)
            .first);
    await tester.pumpAndSettle();
    await tester.tap(completed);
    await tester.pumpAndSettle();
    expect(sent('/organizer/events').single.url.queryParameters['phase'],
        'COMPLETED');

    requests.clear();
    await tester.tap(find.widgetWithText(ChoiceChip, tr('org.tab.sales')));
    await tester.pumpAndSettle();
    // Leaving the tab drops the filter.
    expect(sent('/events/organizer/3'), hasLength(1));
    final line =
        find.text(tr('att.line', {'in': 6, 'all': 8, 'absent': 2}));
    await tester.scrollUntilVisible(line, 200,
        scrollable: find.byType(Scrollable).last);
    expect(line, findsOneWidget);
  });

  testWidgets('History lists activity, filters it and loads more',
      (tester) async {
    await show(tester, EventHistoryScreen(event: EventInfo.fromJson(_event)));
    expect(find.textContaining('Published the event'), findsOneWidget);
    await tester.scrollUntilVisible(find.text(tr('hist.more')), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text(tr('hist.more')));
    await tester.pumpAndSettle();
    expect(requests.last.url.queryParameters['page'], '1');
    expect(find.text(tr('hist.more')), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, 800));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('hist.allEntities')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('hist.entity.ORDER')).last);
    await tester.pumpAndSettle();
    expect(requests.last.url.queryParameters['entityType'], 'ORDER');
    expect(requests.last.url.queryParameters['page'], '0');
  });

  testWidgets('Admin tabs search, monitor, review and save fees',
      (tester) async {
    await show(tester, const AdminToolsScreen());
    Future<void> open(String key) async {
      final tab = find.widgetWithText(Tab, tr(key));
      await tester.ensureVisible(tab);
      await tester.pumpAndSettle();
      await tester.tap(tab);
      await tester.pumpAndSettle();
    }

    await open('adm.events');
    await tester.enterText(find.byType(TextField), 'jazz');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(sent('/admin/events').last.url.queryParameters['q'], 'jazz');

    await open('adm.orders');
    expect(find.textContaining('buyer@example.org'), findsOneWidget);
    expect(find.text(tr('adm.truncated', {'n': 1})), findsOneWidget);

    await open('adm.payments');
    expect(find.textContaining('REF-1'), findsOneWidget);
    await open('adm.refunds');
    expect(sent('/admin/refunds'), isNotEmpty);

    await open('adm.reports');
    expect(sent('/admin/event-reports').last.url.queryParameters['status'],
        'OPEN');
    await tester.tap(find.text(tr('adm.dismiss')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('adm.confirm')));
    await tester.pumpAndSettle();
    expect(jsonDecode(sent('/admin/event-reports/4/review').single.body),
        {'outcome': 'DISMISSED'});

    await open('adm.settings');
    await tester.enterText(find.byType(TextFormField).last, '99');
    await tester.tap(find.text(tr('save')));
    await tester.pumpAndSettle();
    expect(find.text(tr('adm.range', {'max': 50})), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, '3,5');
    await tester.tap(find.text(tr('save')));
    await tester.pumpAndSettle();
    final put = sent('/admin/settings').where((r) => r.method == 'PUT').single;
    expect(jsonDecode(put.body),
        {'activationFeeKzt': 5000, 'processingFeePercent': 3.5});

    await open('adm.export');
    expect(find.text(tr('adm.report.payouts')), findsOneWidget);
  });
}
