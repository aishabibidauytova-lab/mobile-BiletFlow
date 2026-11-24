import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/models/models.dart';
import 'package:mobile/payment/bank_page.dart';
import 'package:mobile/services/api_service.dart';

void main() {
  const order = {
    'id': 7,
    'eventId': 1,
    'items': [],
    'status': 'PENDING',
    'totalAmount': 2000,
  };
  for (final provider in ['FREE', 'SIMULATED', 'HALYK', 'UNKNOWN']) {
    test('Payment selects the $provider flow', () async {
      final calls = <String>[];
      final service = BiletFlowApi(
        client: MockClient((request) async {
          final path = request.url.path.split('/').last;
          calls.add(path);
          expect(request.method, 'POST');
          final result = path == 'payment-session'
              ? {'provider': provider}
              : order;
          return http.Response(jsonEncode(result), 200);
        }),
      );
      final result = service.startPayment(
        Order.fromJson({...order, if (provider == 'FREE') 'totalAmount': 0}),
        openBank: (session) async {
          calls.add('bank');
        },
        onSimulation: () => calls.add('demo'),
      );
      if (provider == 'UNKNOWN') {
        await expectLater(result, throwsA(isA<ApiException>()));
      } else {
        await result;
      }
      expect(calls, switch (provider) {
        'FREE' => ['pay'],
        'SIMULATED' => ['payment-session', 'demo', 'pay'],
        'HALYK' => ['payment-session', 'bank', 'payment-check'],
        _ => ['payment-session'],
      });
    });
  }

  test(
    'A refund posts the optional reason and preserves refunded statuses',
    () async {
      final service = BiletFlowApi(
        client: MockClient((request) async {
          expect(request.url.path, '/api/orders/7/refund');
          expect(request.method, 'POST');
          expect(jsonDecode(request.body), {'reason': 'Requested'});
          return http.Response(
            jsonEncode({...order, 'status': 'REFUNDED'}),
            200,
          );
        }),
      );
      expect(
        (await service.refundOrder(7, ' Requested ')).status,
        OrderStatus.refunded,
      );
      expect(
        Ticket.fromJson({'id': 1, 'status': 'REFUNDED'}).status,
        TicketStatus.refunded,
      );
      expect(
        EventOrder.fromJson({'status': 'REFUNDED'}).status,
        OrderStatus.refunded,
      );
    },
  );

  test('Only official bank scripts can receive a session', () {
    final session = {
      'payment': {'description': '</script><test>'},
      'scriptUrl': 'https://example.com/pay.js',
    };
    expect(() => BankPage.fromSession(session), throwsA(isA<ApiException>()));
    final page = BankPage.fromSession({
      ...session,
      'scriptUrl': 'https://test-epay.epayment.kz/payform/payment-api.js',
    });
    expect(page.html, isNot(contains('</script><test>')));
  });
}
