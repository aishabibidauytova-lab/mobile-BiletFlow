import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/models/models.dart';
import 'package:mobile/services/api_service.dart';

void main() {
  test(
    'Downloads the ticket with authorization and preserves binary data',
    () async {
      final bytes = [...ascii.encode('%PDF-1.7'), 0, 255, 128];
      final api = BiletFlowApi(
        client: MockClient((req) async {
          expect(req.url.path, '/api/tickets/27/pdf');
          expect(req.headers['Authorization'], 'Bearer test-token');
          return http.Response.bytes(bytes, 200);
        }),
      )..token = 'test-token';
      expect(await api.getTicketPdf(27), bytes);
    },
  );

  test(
    'Rejects HTML or empty success responses before opening the print dialog',
    () async {
      for (final body in ['', '<html>Sign in</html>']) {
        final api = BiletFlowApi(
          client: MockClient((_) async => http.Response(body, 200)),
        );
        await expectLater(api.getTicketPdf(27), throwsA(isA<ApiException>()));
      }
    },
  );

  test(
    'Displays the server error for a ticket that cannot be downloaded',
    () async {
      final api = BiletFlowApi(
        client: MockClient(
          (_) async => http.Response('{"message":"Ticket unavailable"}', 403),
        ),
      );
      await expectLater(
        api.getTicketPdf(27),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Ticket unavailable',
          ),
        ),
      );
    },
  );
}
