// Models mirror the backend DTOs (see /v3/api-docs on the server).

DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v as String);

num _num(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;

/// Spring `Page<T>`: only the fields the app needs.
class PageResult<T> {
  final List<T> items;
  final bool last;
  const PageResult(this.items, this.last);

  factory PageResult.fromJson(
          Map<String, dynamic> j, T Function(Map<String, dynamic>) parse) =>
      PageResult(
        (j['content'] as List? ?? [])
            .map((e) => parse(e as Map<String, dynamic>))
            .toList(),
        (j['last'] ?? true) as bool,
      );
}

class AppUser {
  final int id;
  final String email;
  final String role;
  const AppUser({required this.id, required this.email, required this.role});

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as int,
        email: (j['email'] ?? '') as String,
        role: (j['role'] ?? '') as String,
      );
}

class Venue {
  final String name;
  final String address;
  const Venue(this.name, this.address);

  factory Venue.fromJson(Map<String, dynamic> j) =>
      Venue((j['name'] ?? '') as String, (j['address'] ?? '') as String);
}

class EventInfo {
  final int id;
  final String title;
  final String description;
  final String category;
  final DateTime? startTime;
  final DateTime? endTime;
  final DateTime? registrationClosingTime;
  final String status; // DRAFT, PUBLISHED, CANCELLED
  final Venue? venue;

  const EventInfo({
    required this.id,
    required this.title,
    this.description = '',
    this.category = '',
    this.startTime,
    this.endTime,
    this.registrationClosingTime,
    this.status = 'PUBLISHED',
    this.venue,
  });

  bool get isCancelled => status == 'CANCELLED';

  /// "04.11.2026 15:00 • Demo Concert Hall"
  String get subtitle => [
        if (startTime != null) formatDateTime(startTime!),
        if (venue != null) venue!.name,
      ].join(' • ');

  factory EventInfo.fromJson(Map<String, dynamic> j) => EventInfo(
        id: j['id'] as int,
        title: (j['title'] ?? '') as String,
        description: (j['description'] ?? '') as String,
        category: (j['category'] ?? '') as String,
        startTime: _date(j['startTime']),
        endTime: _date(j['endTime']),
        registrationClosingTime: _date(j['registrationClosingTime']),
        status: (j['status'] ?? 'PUBLISHED') as String,
        venue: j['venue'] != null
            ? Venue.fromJson(j['venue'] as Map<String, dynamic>)
            : null,
      );
}

class TicketType {
  final int id;
  final String name;
  final String description;
  final num price;
  final int available;
  final int maxPerOrder;
  final DateTime? salesStart;
  final DateTime? salesEnd;
  final bool hidden;

  const TicketType({
    required this.id,
    required this.name,
    this.description = '',
    required this.price,
    required this.available,
    this.maxPerOrder = 10,
    this.salesStart,
    this.salesEnd,
    this.hidden = false,
  });

  bool get isFree => price == 0;

  bool get onSale {
    final now = DateTime.now();
    if (salesStart != null && now.isBefore(salesStart!)) return false;
    if (salesEnd != null && now.isAfter(salesEnd!)) return false;
    return available > 0;
  }

  factory TicketType.fromJson(Map<String, dynamic> j) => TicketType(
        id: j['id'] as int,
        name: (j['name'] ?? '') as String,
        description: (j['description'] ?? '') as String,
        price: _num(j['price']),
        available: _num(j['available']).toInt(),
        maxPerOrder: _num(j['maxPerOrder'] ?? 10).toInt(),
        salesStart: _date(j['salesStart']),
        salesEnd: _date(j['salesEnd']),
        hidden: (j['hidden'] ?? false) as bool,
      );
}

enum OrderStatus { pending, paid, cancelled, expired }

class OrderItem {
  final String ticketTypeName;
  final int quantity;
  final num unitPrice;
  const OrderItem(this.ticketTypeName, this.quantity, this.unitPrice);

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        (j['ticketTypeName'] ?? '') as String,
        _num(j['quantity']).toInt(),
        _num(j['unitPrice']),
      );
}

class Order {
  final int id;
  final int eventId;
  final String eventTitle;
  final OrderStatus status;
  final num totalAmount;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final List<OrderItem> items;

  const Order({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.status,
    required this.totalAmount,
    this.createdAt,
    this.expiresAt,
    this.items = const [],
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j['id'] as int,
        eventId: j['eventId'] as int,
        eventTitle: (j['eventTitle'] ?? '') as String,
        status: OrderStatus.values.firstWhere(
          (s) => s.name.toUpperCase() == j['status'],
          orElse: () => OrderStatus.pending,
        ),
        totalAmount: _num(j['totalAmount']),
        createdAt: _date(j['createdAt']),
        expiresAt: _date(j['expiresAt']),
        items: (j['items'] as List? ?? [])
            .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

enum TicketStatus { valid, used, cancelled }

class Ticket {
  final int id;
  final String code;
  final TicketStatus status;
  final int orderId;
  final int eventId;
  final String eventTitle;
  final String ticketTypeName;
  final String attendeeEmail;
  final DateTime? usedAt;

  const Ticket({
    required this.id,
    required this.code,
    required this.status,
    required this.orderId,
    required this.eventId,
    required this.eventTitle,
    required this.ticketTypeName,
    required this.attendeeEmail,
    this.usedAt,
  });

  factory Ticket.fromJson(Map<String, dynamic> j) => Ticket(
        id: j['id'] as int,
        code: (j['code'] ?? '') as String,
        status: TicketStatus.values.firstWhere(
          (s) => s.name.toUpperCase() == j['status'],
          orElse: () => TicketStatus.valid,
        ),
        orderId: _num(j['orderId']).toInt(),
        eventId: _num(j['eventId']).toInt(),
        eventTitle: (j['eventTitle'] ?? '') as String,
        ticketTypeName: (j['ticketTypeName'] ?? '') as String,
        attendeeEmail: (j['attendeeEmail'] ?? '') as String,
        usedAt: _date(j['usedAt']),
      );
}

class EventStats {
  final int checkedIn;
  final int total;
  const EventStats(this.checkedIn, this.total);

  factory EventStats.fromJson(Map<String, dynamic> j) => EventStats(
      _num(j['checkedIn']).toInt(), _num(j['registered']).toInt());
}

enum ScanOutcome {
  success, // valid ticket, check-in recorded
  alreadyUsed, // ticket already checked in
  cancelled,
  invalid, // unknown / tampered ticket
  notTicket, // QR is not an admission ticket (e.g. Campaign QR)
  wrongEvent, // ticket belongs to another event
  error, // network / server problem
}

class ScanResult {
  final ScanOutcome outcome;
  final Ticket? ticket;
  final String? message;
  final DateTime? checkedInAt;
  const ScanResult(this.outcome, {this.ticket, this.message, this.checkedInAt});

  static const _outcomes = {
    'CHECKED_IN': ScanOutcome.success,
    'ALREADY_USED': ScanOutcome.alreadyUsed,
    'CANCELLED': ScanOutcome.cancelled,
    'WRONG_EVENT': ScanOutcome.wrongEvent,
    'INVALID': ScanOutcome.invalid,
  };

  factory ScanResult.fromJson(Map<String, dynamic> j) => ScanResult(
        _outcomes[j['result']] ?? ScanOutcome.error,
        ticket: j['ticket'] != null
            ? Ticket.fromJson(j['ticket'] as Map<String, dynamic>)
            : null,
        message: j['message'] as String?,
        checkedInAt: _date(j['checkedInAt']),
      );
}

class ApiException implements Exception {
  final String message;
  final bool unauthorized;
  ApiException(this.message, {this.unauthorized = false});
  @override
  String toString() => message;
}

/// Campaign QR codes are https links to an event page and must never grant
/// entry (SRS 4.14). Everything else is sent to the server, which validates it.
class QrPayload {
  static bool looksLikeLink(String raw) =>
      raw.startsWith('http://') || raw.startsWith('https://');
}

String _two(int n) => n.toString().padLeft(2, '0');

String formatDateTime(DateTime d) =>
    '${_two(d.day)}.${_two(d.month)}.${d.year} ${_two(d.hour)}:${_two(d.minute)}';

String formatTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// "1 500 ₸", or "Бесплатно" for zero.
String formatPrice(num p) {
  if (p == 0) return 'Бесплатно';
  final s = p.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return '$b ₸';
}
