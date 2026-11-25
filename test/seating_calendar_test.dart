import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/l10n/l10n.dart';
import 'package:mobile/models/models.dart';
import 'package:mobile/screens/admin_tools_screen.dart';
import 'package:mobile/screens/event_detail_screen.dart';
import 'package:mobile/screens/manage_event_screen.dart';
import 'package:mobile/screens/seating_setup_screen.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/widgets/calendar_button.dart';
import 'package:mobile/widgets/seat_map_view.dart';

const _event = {
  'id': 8,
  'title': 'Final',
  'startTime': '2030-05-01T19:00:00',
  'status': 'PUBLISHED',
  'seatingMode': 'ASSIGNED',
};

const _stand = {
  'id': 2,
  'key': 'N1',
  'name': 'North stand',
  'kind': 'SEATED',
  'x': 0,
  'y': 0,
  'width': 400,
  'height': 200,
  'capacity': 3,
  'onSale': true,
  'ticketTypeId': 15,
  'ticketTypeName': 'Stands',
  'price': 9000,
  'available': 2,
};

const _map = {
  'seatingMode': 'ASSIGNED',
  'width': 400,
  'height': 500,
  'sections': [
    _stand,
    {
      'id': 1,
      'key': 'FIELD',
      'name': 'Field',
      'kind': 'STANDING',
      'x': 0,
      'y': 250,
      'width': 400,
      'height': 200,
      'onSale': true,
      'ticketTypeId': 13,
      'price': 6000,
      'available': 100,
    },
  ],
};

const _seats = [
  {'id': 101, 'row': '1', 'number': 1, 'x': 10, 'y': 10, 'status': 'AVAILABLE'},
  {'id': 102, 'row': '1', 'number': 2, 'x': 20, 'y': 10, 'status': 'SOLD'},
  {'id': 103, 'row': '1', 'number': 3, 'x': 30, 'y': 10, 'status': 'AVAILABLE'},
];

Object _answer(http.Request r) {
  final path = r.url.path.replaceFirst('/api', '');
  if (r.method == 'POST' && path.endsWith('/ticket-types')) {
    return {'id': 17, 'name': 'VIP', 'price': 0, 'available': 0};
  }
  return switch (path) {
    '/events/8' => _event,
    '/events/8/ticket-types' => [
        {'id': 13, 'name': 'Fan field', 'price': 6000, 'available': 100},
        {
          'id': 15,
          'name': 'Stands',
          'price': 9000,
          'available': 2,
          'maxPerOrder': 1,
        },
        {'id': 16, 'name': 'Unused', 'price': 100, 'available': 5},
      ],
    '/events/8/seat-map' || '/events/8/seating' => _map,
    '/events/8/seat-map/sections/2' => {'section': _stand, 'seats': _seats},
    '/orders/quote' => {'subtotalAmount': 15000, 'totalAmount': 15000},
    '/orders' => {'message': 'Seat is taken'},
    '/events/8/staff' => [],
    '/events/8/calendar' => {
        'cancelled': false,
        'googleCalendarUrl': 'https://calendar.google.com/x',
      },
    '/venues/seating-layouts' => [
        {'key': 'arena', 'name': 'Arena', 'capacity': 100},
      ],
    '/venues' => {
        'content': [
          {'id': 4, 'name': 'Hall', 'address': 'Abay 1'},
        ],
      },
    _ => {'content': []},
  };
}

void main() {
  final requests = <http.Request>[];

  setUpAll(() {
    http.runWithClient(
      () => api.token = 'test',
      () => MockClient((request) async {
        requests.add(request);
        final failed =
            request.url.path == '/api/orders' && request.method == 'POST';
        return http.Response.bytes(utf8.encode(jsonEncode(_answer(request))),
            failed ? 409 : 200);
      }),
    );
  });
  setUp(requests.clear);

  Future<void> show(WidgetTester tester, Widget screen) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  Iterable<http.Request> sent(String path) =>
      requests.where((r) => r.url.path == '/api$path');

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  test('Tickets describe their seat', () {
    final seated = Ticket.fromJson({
      'id': 1,
      'ticketTypeName': 'Stands',
      'sectionName': 'North',
      'rowLabel': '3',
      'seatNumber': 12,
    });
    expect(seated.seat,
        'North · ${tr('seat.rowSeat', {'row': '3', 'n': 12})}');
    expect(
        Ticket.fromJson({'id': 2, 'sectionName': 'Field'}).seat, 'Field');
    final general = Ticket.fromJson({'id': 3, 'ticketTypeName': 'Standard'});
    expect(general.typeAndSeat, 'Standard');
    expect(
        Seat.fromJson({'id': 1, 'status': 'SOMETHING_NEW'}).status,
        SeatStatus.unavailable);
  });

  testWidgets('An attendee picks a seat and a standing ticket, then orders',
      (tester) async {
    await show(tester, EventDetailScreen(event: EventInfo.fromJson(_event)));
    expect(find.text(tr('seat.notForSale')), findsOneWidget);

    await tapVisible(tester,
        find.widgetWithText(OutlinedButton, tr('seat.choose')));
    // The first section with free seats opens by itself.
    final grid = find.byType(SeatGrid);
    await tester.ensureVisible(grid);
    await tester.pumpAndSettle();

    // The closest seats are 10 apart and drawn 32 pixels apart; the row label
    // comes first, 1.2 seats before seat 1.
    const step = SeatGrid.spacing;
    final seat1 =
        tester.getTopLeft(grid) + const Offset(step * 2.2, step);
    await tester.tapAt(seat1 + const Offset(step, 0)); // sold
    await tester.pumpAndSettle();
    expect(find.byType(InputChip, skipOffstage: false), findsNothing);
    await tester.tapAt(seat1);
    await tester.pumpAndSettle();
    expect(find.byType(InputChip, skipOffstage: false), findsOneWidget);
    // This type allows one ticket per order.
    await tester.tapAt(seat1 + const Offset(step * 2, 0));
    await tester.pumpAndSettle();
    expect(find.byType(InputChip, skipOffstage: false), findsOneWidget);
    expect(find.text(tr('seat.typeLimit', {'name': 'Stands', 'n': 1})),
        findsOneWidget);

    await tester.tap(find.textContaining(tr('seat.done')));
    await tester.pumpAndSettle();

    // One standing ticket, by count.
    await tapVisible(tester, find.byTooltip(tr('ticketType.more')).first);
    await tester.tap(find.widgetWithText(FilledButton, tr('detail.order')));
    // The page's button spins while the checkout sheet is open, so the
    // animations never settle.
    Future<void> wait() async {
      for (var n = 0; n < 5; n++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    await wait();
    final place =
        find.widgetWithText(FilledButton, tr('checkout.placeOrder'));
    await tester.ensureVisible(place);
    await wait();
    await tester.tap(place);
    await wait();

    const body = {
      'eventId': 8,
      'items': [
        {'ticketTypeId': 13, 'quantity': 1},
      ],
      'seatIds': [101],
    };
    expect(jsonDecode(sent('/orders/quote').single.body), body);
    expect(jsonDecode(sent('/orders').single.body), body);
    expect(find.text('Seat is taken'), findsOneWidget);
  });

  testWidgets('Organizer assigns a section and blocks a row', (tester) async {
    await show(tester, SeatingSetupScreen(event: EventInfo.fromJson(_event)));

    final dropdown = find.byType(DropdownButtonFormField<int?>).first;
    await tapVisible(tester, dropdown);
    await tester.tap(find.text(tr('seat.notForSale')).last);
    await tester.pumpAndSettle();
    final assign = sent('/events/8/seating/sections/2').single;
    expect(assign.method, 'PUT');
    expect(jsonDecode(assign.body), {'ticketTypeId': null});

    await tapVisible(tester, find.text(tr('seat.manage')));
    await tester.tap(find.text(tr('seat.row', {'row': '1'})));
    await tester.pumpAndSettle();
    await tester.tap(find.text('${tr('seat.block')} (2)'));
    await tester.pumpAndSettle();
    // The sold seat stays as it is.
    expect(jsonDecode(sent('/events/8/seating/seats').single.body), {
      'seatIds': [101, 103],
      'blocked': true,
    });
  });

  testWidgets('With assigned seating the ticket quantity is not asked',
      (tester) async {
    await show(tester, ManageEventScreen(event: EventInfo.fromJson(_event)));
    await tester.scrollUntilVisible(find.text(tr('manage.ticketTypes')), 200,
        scrollable: find.byType(Scrollable).first);
    await tapVisible(tester, find.text(tr('add')).first);
    expect(find.text(tr('seat.quantityHint')), findsOneWidget);
    expect(find.text(tr('tt.quantity')), findsNothing);
    await tester.enterText(find.byType(TextFormField).first, 'VIP');
    await tester.tap(find.text(tr('save')));
    await tester.pumpAndSettle();
    final post = requests.firstWhere((r) => r.method == 'POST');
    expect(jsonDecode(post.body), isNot(contains('quantity')));
  });

  testWidgets('Admin gives a venue a seating plan', (tester) async {
    await show(tester, const AdminToolsScreen());
    await tapVisible(tester, find.widgetWithText(Tab, tr('adm.venues')));
    await tapVisible(tester, find.byType(DropdownButtonFormField<String?>));
    await tester.tap(find.text('Arena · 100').last);
    await tester.pumpAndSettle();
    expect(jsonDecode(sent('/venues/4/seating-layout').single.body),
        {'seatingLayout': 'arena'});
  });

  testWidgets('An event can be added to a calendar', (tester) async {
    await show(tester, const Scaffold(body: CalendarButton(eventId: 8)));
    await tester.tap(find.text(tr('cal.add')));
    await tester.pumpAndSettle();
    expect(find.text('Google Calendar'), findsOneWidget);
    expect(find.text('Outlook'), findsNothing); // no link for it
    expect(find.text(tr('cal.ics')), findsOneWidget);
  });
}
