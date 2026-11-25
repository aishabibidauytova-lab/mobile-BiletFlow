import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/scan_gate.dart';

void main() {
  test('A code is scanned again only after it has left the camera', () {
    var now = DateTime(2030);
    final gate = ScanGate(now: () => now);
    bool read(String code, int ms, {bool busy = false}) {
      now = now.add(Duration(milliseconds: ms));
      return gate.accept(code, busy: busy);
    }

    expect(read('A', 0), isTrue);
    // Held in view, while the result shows and long after it closes.
    for (var i = 0; i < 30; i++) {
      expect(read('A', 300, busy: i < 13), isFalse);
    }
    // Taken away and shown again: the server is asked again.
    expect(read('A', 2500), isTrue);
  });

  test('Another code waits until the result on screen is gone', () {
    var now = DateTime(2030);
    final gate = ScanGate(now: () => now);
    expect(gate.accept('A'), isTrue);
    expect(gate.accept('B', busy: true), isFalse);
    expect(gate.accept('B'), isTrue);
  });
}
