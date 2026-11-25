import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';
import 'package:mobile/screens/login_screen.dart';

void main() {
  // Starts the whole app, signed out, normally and from a campaign link.
  for (final route in ['/', '/events/5?promo=abc']) {
    testWidgets('The app starts at $route', (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      tester.platformDispatcher.defaultRouteNameTestValue = route;
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
      await tester.pumpWidget(const BiletFlowApp());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  }
}
