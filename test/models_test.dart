import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/models.dart';

// JSON samples follow the backend's OpenAPI schemas (/v3/api-docs).
void main() {
  test('Order reads promo code, discount and attendee name', () {
    final o = Order.fromJson({
      'id': 7,
      'eventId': 2,
      'eventTitle': 'Jazz',
      'status': 'PENDING',
      'attendeeName': 'Aigerim',
      'subtotalAmount': 10000,
      'discountAmount': 2000,
      'totalAmount': 8000,
      'promoCode': 'JAZZ20',
      'items': [
        {'ticketTypeId': 1, 'ticketTypeName': 'VIP', 'quantity': 2, 'unitPrice': 5000},
      ],
    });
    expect(o.status, OrderStatus.pending);
    expect(o.subtotalAmount, 10000);
    expect(o.discountAmount, 2000);
    expect(o.totalAmount, 8000);
    expect(o.promoCode, 'JAZZ20');
    expect(o.attendeeName, 'Aigerim');
    expect(o.items.single.quantity, 2);
  });

  test('Order without promo fields falls back to total as subtotal', () {
    final o = Order.fromJson(
        {'id': 1, 'eventId': 1, 'status': 'PAID', 'totalAmount': 0, 'items': []});
    expect(o.subtotalAmount, 0);
    expect(o.discountAmount, 0);
    expect(o.promoCode, isNull);
  });

  test('EventInfo reads suspension and paid sales flags', () {
    final e = EventInfo.fromJson({
      'id': 3,
      'title': 'Concert',
      'paidSalesActive': true,
      'suspended': true,
      'suspensionReason': 'Fraud check',
    });
    expect(e.paidSalesActive, isTrue);
    expect(e.suspended, isTrue);
    expect(e.suspensionReason, 'Fraud check');
  });

  test('Campaign parses statistics and formats the discount', () {
    final c = Campaign.fromJson({
      'id': 4,
      'eventId': 2,
      'name': 'Students',
      'code': 'STUD10',
      'discountType': 'PERCENT',
      'discountValue': 10,
      'maxRedemptions': 50,
      'enabled': true,
      'redemptions': 5,
      'remainingRedemptions': 45,
      'ticketsSold': 6,
      'grossRevenue': 30000,
      'discountAmount': 3000,
      'netRevenue': 27000,
    });
    expect(c.discountLabel, '−10%');
    expect(c.remainingRedemptions, 45);
    expect(c.netRevenue, 27000);
  });

  test('Activation parses the checklist', () {
    final a = Activation.fromJson({
      'eventId': 2,
      'eventTitle': 'Jazz',
      'status': 'IN_PROGRESS',
      'simulated': true,
      'feeAmount': 5000,
      'readyToActivate': false,
      'checklist': [
        {'key': 'PAID_TICKET_TYPE', 'label': 'Create a paid ticket type', 'done': true},
        {'key': 'FEE_PAID', 'label': 'Pay the activation fee', 'done': false},
      ],
    });
    expect(a.checklist.length, 2);
    expect(a.checklist.first.done, isTrue);
    expect(a.checklist.last.key, 'FEE_PAID');
    expect(a.readyToActivate, isFalse);
  });

  test('SupportCaseDetail parses the case and its messages', () {
    final d = SupportCaseDetail.fromJson({
      'supportCase': {
        'id': 9,
        'type': 'ATTENDEE',
        'category': 'PAYMENT',
        'subject': 'Charged twice',
        'status': 'WAITING_FOR_CUSTOMER',
        'escalated': false,
        'requesterId': 11,
        'requesterEmail': 'a@b.kz',
        'orderId': 7,
      },
      'messages': [
        {'id': 1, 'authorName': 'a@b.kz', 'fromStaff': false, 'body': 'Hi'},
        {'id': 2, 'authorName': 'Organizer', 'fromStaff': true, 'body': 'Checking'},
      ],
    });
    expect(d.supportCase.status, 'WAITING_FOR_CUSTOMER');
    expect(d.supportCase.orderId, 7);
    expect(d.messages.last.fromStaff, isTrue);
  });

  test('SalesSummary parses totals and per-event sales', () {
    final s = SalesSummary.fromJson({
      'events': [
        {
          'eventId': 2,
          'eventTitle': 'Jazz',
          'capacity': 300,
          'paidOrders': 3,
          'ticketsSold': 5,
          'revenue': 25000,
          'discounts': 2000,
          'netRevenue': 23000,
          'ticketTypes': [
            {'name': 'VIP', 'price': 5000, 'quantity': 50, 'sold': 5, 'reserved': 1, 'available': 44, 'revenue': 25000},
          ],
          'salesByDay': [
            {'date': '2026-11-10', 'paidOrders': 3, 'ticketsSold': 5, 'revenue': 25000},
          ],
        },
      ],
      'totals': {'events': 1, 'paidOrders': 3, 'ticketsSold': 5, 'revenue': 25000, 'netRevenue': 23000},
    });
    expect(s.totals.ticketsSold, 5);
    expect(s.events.single.figures.netRevenue, 23000);
    expect(s.events.single.ticketTypes.single.available, 44);
    expect(s.events.single.salesByDay.single.date, DateTime(2026, 11, 10));
  });

  test('Campaign QR links are never admission tickets', () {
    expect(QrPayload.looksLikeLink('https://biletflow.kz/events/2?promo=abc'), isTrue);
    expect(QrPayload.looksLikeLink('BF-7-9f3a'), isFalse);
  });
}
