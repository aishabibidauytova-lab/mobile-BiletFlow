enum TicketStatus { valid, checkedIn, cancelled, refunded }

enum ScanOutcome {
  success, // valid ticket, check-in recorded
  alreadyUsed, // ticket already checked in
  cancelled,
  refunded,
  invalid, // unknown / tampered ticket
  notTicket, // QR is not an admission ticket (e.g. Campaign QR)
  wrongEvent, // ticket belongs to another event
  error, // network / server problem
}

class EventInfo {
  final String id;
  final String title;
  final String subtitle;
  final bool canUndo; // Event Admin is authorized to reverse check-ins

  const EventInfo({
    required this.id,
    required this.title,
    required this.subtitle,
    this.canUndo = true,
  });

  factory EventInfo.fromJson(Map<String, dynamic> j) => EventInfo(
        id: j['id'].toString(),
        title: j['title'] as String,
        subtitle: (j['subtitle'] ?? '') as String,
        canUndo: (j['canUndo'] ?? true) as bool,
      );
}

class EventStats {
  final int checkedIn;
  final int total;
  const EventStats(this.checkedIn, this.total);

  factory EventStats.fromJson(Map<String, dynamic> j) =>
      EventStats(j['checkedIn'] as int, j['total'] as int);
}

class Attendee {
  final String ticketId;
  final String name;
  final String email;
  final String ticketType;
  final String? seat; // "Секция A, ряд 3, место 12"
  final TicketStatus status;
  final DateTime? checkedInAt;

  const Attendee({
    required this.ticketId,
    required this.name,
    required this.email,
    required this.ticketType,
    this.seat,
    required this.status,
    this.checkedInAt,
  });

  Attendee copyWith({TicketStatus? status, DateTime? checkedInAt}) => Attendee(
        ticketId: ticketId,
        name: name,
        email: email,
        ticketType: ticketType,
        seat: seat,
        status: status ?? this.status,
        checkedInAt: checkedInAt,
      );

  factory Attendee.fromJson(Map<String, dynamic> j) => Attendee(
        ticketId: j['ticketId'] as String,
        name: j['name'] as String,
        email: (j['email'] ?? '') as String,
        ticketType: (j['ticketType'] ?? '') as String,
        seat: j['seat'] as String?,
        status: TicketStatus.values.firstWhere(
          (s) => s.name == j['status'],
          orElse: () => TicketStatus.valid,
        ),
        checkedInAt: j['checkedInAt'] != null
            ? DateTime.tryParse(j['checkedInAt'] as String)
            : null,
      );
}

class ScanResult {
  final ScanOutcome outcome;
  final Attendee? attendee;
  final String? message;
  const ScanResult(this.outcome, {this.attendee, this.message});
}

class ApiException implements Exception {
  final String message;
  final bool unauthorized;
  ApiException(this.message, {this.unauthorized = false});
  @override
  String toString() => message;
}

/// Admission QR payloads look like `BF1:<signed-ticket-token>`.
/// Anything else (e.g. a Campaign QR, which is an https link) must never
/// grant entry (SRS 4.14). The server enforces this too.
class QrPayload {
  static const prefix = 'BF1:';

  static bool isAdmissionTicket(String raw) => raw.startsWith(prefix);

  static bool looksLikeLink(String raw) =>
      raw.startsWith('http://') || raw.startsWith('https://');
}
