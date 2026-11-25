import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/models.dart';
import 'package:mobile/widgets/scrolling.dart';
import 'package:mobile/widgets/seat_map_view.dart';

void main() {
  Widget app(Widget body) => MaterialApp(
      scrollBehavior: const AppScrollBehavior(), home: Scaffold(body: body));

  test('Finished events are over; upcoming and running ones are not', () {
    EventInfo event(Map<String, dynamic> j) =>
        EventInfo.fromJson({'id': 1, ...j});
    expect(event({'phase': 'COMPLETED'}).isOver, isTrue);
    // The server's phase wins over the clock.
    expect(
        event({'phase': 'ACTIVE', 'endTime': '2000-01-01T00:00:00'}).isOver,
        isFalse);
    expect(event({'startTime': '2000-01-01T00:00:00'}).isOver, isTrue);
    expect(event({'startTime': '2999-01-01T00:00:00'}).isOver, isFalse);
  });

  testWidgets('A strip moves by mouse drag and by mouse wheel', (tester) async {
    await tester.pumpWidget(app(ListView(children: [
      SizedBox(
        height: 60,
        child: HorizontalStrip(children: [
          for (var i = 0; i < 30; i++)
            SizedBox(width: 100, child: Text('item $i')),
        ]),
      ),
      const SizedBox(height: 2000),
    ])));
    final strip = find.byType(HorizontalStrip);
    double left() => tester.getTopLeft(find.text('item 3')).dx;

    final start = left();
    await tester.drag(strip, const Offset(-100, 0),
        kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    final dragged = left();
    expect(dragged, lessThan(start));

    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(tester.getCenter(strip)));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 60)));
    await tester.pumpAndSettle();
    expect(left(), dragged - 60);
    // The page behind did not move.
    expect(tester.getTopLeft(strip).dy, 0);
  });

  testWidgets('Every row of a large section can be reached', (tester) async {
    Seat? tapped;
    final seats = [
      for (var row = 1; row <= 25; row++)
        for (var n = 1; n <= 40; n++)
          Seat(
              id: row * 100 + n,
              row: '$row',
              number: n,
              x: n * 10,
              y: row * 10),
    ];
    await tester.pumpWidget(app(Center(
      child: SizedBox(
        width: 360,
        height: 300,
        child: SeatGrid(
            seats: seats,
            selected: const {},
            enabled: (_) => true,
            onTap: (s) => tapped = s),
      ),
    )));
    final grid = find.byType(SeatGrid);
    await tester.drag(grid, const Offset(-3000, -3000));
    await tester.pumpAndSettle();
    // Zooming keeps working after the move.
    await tester.tap(find.byIcon(Icons.zoom_out));
    await tester.tap(find.byIcon(Icons.zoom_in));
    await tester.pumpAndSettle();
    await tester.drag(grid, const Offset(-3000, -3000));
    await tester.pumpAndSettle();
    // The far corner is now on screen, past the edge margin.
    final corner = tester.getBottomRight(grid);
    for (var d = 130.0; d < 200 && tapped == null; d += 8) {
      await tester.tapAt(corner - Offset(d, d));
      await tester.pump();
    }
    expect(tapped?.row, '25');
    expect(tapped!.number, greaterThan(35));
  });
}
