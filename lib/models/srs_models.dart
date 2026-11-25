part of 'models.dart';

/// "2026-11-26": the date-only format of the report and history filters.
String isoDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

/// Event lifecycle used by the history filters (SRS 4.16).
const eventPhases = ['UPCOMING', 'ACTIVE', 'COMPLETED', 'CANCELLED'];

const reportReasons = [
  'FRAUD', 'MISLEADING', 'INAPPROPRIATE', 'SPAM', 'OTHER',
];

// --- Attendance and history ----------------------------------------------------

class TicketTypeAttendance {
  final String name;
  final int ticketHolders;
  final int checkedIn;
  final int absent;
  const TicketTypeAttendance(
      this.name, this.ticketHolders, this.checkedIn, this.absent);

  factory TicketTypeAttendance.fromJson(Map<String, dynamic> j) =>
      TicketTypeAttendance(
        (j['name'] ?? '') as String,
        _num(j['ticketHolders']).toInt(),
        _num(j['checkedIn']).toInt(),
        _num(j['absent']).toInt(),
      );
}

class Attendance {
  final int ticketHolders;
  final int checkedIn;
  final int absent;
  final List<TicketTypeAttendance> ticketTypes;
  const Attendance(this.ticketHolders, this.checkedIn, this.absent,
      [this.ticketTypes = const []]);

  /// Share of ticket holders who arrived, 0–100.
  int get percent =>
      ticketHolders == 0 ? 0 : (checkedIn * 100 / ticketHolders).round();

  factory Attendance.fromJson(Map<String, dynamic> j) => Attendance(
        _num(j['ticketHolders']).toInt(),
        _num(j['checkedIn']).toInt(),
        _num(j['absent']).toInt(),
        (j['ticketTypes'] as List? ?? [])
            .map((e) => TicketTypeAttendance.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Actions the server records in an event's history.
const historyActions = [
  'EVENT_CREATED', 'EVENT_UPDATED', 'EVENT_PUBLISHED', 'EVENT_UNPUBLISHED',
  'EVENT_CANCELLED', 'EVENT_DUPLICATED', 'EVENT_SUSPENDED', 'EVENT_UNSUSPENDED',
  'TICKET_TYPE_CREATED', 'TICKET_TYPE_UPDATED', 'TICKET_TYPE_HIDDEN',
  'TICKET_TYPE_UNHIDDEN', 'STAFF_ASSIGNED', 'STAFF_REMOVED',
  'PAYMENT_SUCCEEDED', 'PAYMENT_FAILED', 'ORDER_REFUNDED', 'REFUND_FAILED',
  'REGISTRATION_CANCELLED', 'TICKET_CHECKED_IN', 'TICKET_CHECK_IN_UNDONE',
  'ACTIVATION_FEE_PAID', 'ACTIVATION_TERMS_ACCEPTED', 'PAID_SALES_ACTIVATED',
  'PAID_SALES_SUSPENDED', 'PAID_SALES_UNSUSPENDED', 'PROMO_CAMPAIGN_CREATED',
  'PROMO_CAMPAIGN_DISABLED', 'PROMO_CAMPAIGN_ENABLED',
  'SUPPORT_CASE_ASSIGNED', 'SUPPORT_CASE_STATUS_CHANGED',
  'SUPPORT_CASE_ESCALATED', 'EVENT_REPORT_REVIEWED', 'PAYOUT_SCHEDULED',
  'PAYOUT_HELD', 'PAYOUT_RELEASED', 'PAYOUT_PAID', 'PAYOUT_CANCELLED',
];

const historyEntityTypes = [
  'EVENT', 'TICKET_TYPE', 'ORDER', 'PAYMENT', 'TICKET', 'PROMO_CAMPAIGN',
  'SUPPORT_CASE', 'STAFF_ASSIGNMENT', 'PAID_SALES_ACTIVATION', 'PAYOUT',
];

class HistoryEntry {
  final DateTime? timestamp;
  final String actor;
  final String action;
  final String description;
  const HistoryEntry(this.timestamp, this.actor, this.action, this.description);

  factory HistoryEntry.fromJson(Map<String, dynamic> j) {
    final name = (j['actorName'] ?? '') as String;
    return HistoryEntry(
      _date(j['timestamp']),
      name.isNotEmpty ? name : (j['actorEmail'] ?? '') as String,
      (j['action'] ?? '') as String,
      (j['description'] ?? '') as String,
    );
  }
}

// --- Campaign links --------------------------------------------------------------

class PromoPreview {
  final String code;
  final String discountType; // PERCENT, FIXED
  final num discountValue;
  const PromoPreview(this.code, this.discountType, this.discountValue);

  String get discountLabel => discountType == 'PERCENT'
      ? '−${discountValue.round()}%'
      : '−${formatPrice(discountValue)}';

  factory PromoPreview.fromJson(Map<String, dynamic> j) => PromoPreview(
        (j['code'] ?? '') as String,
        (j['discountType'] ?? 'PERCENT') as String,
        _num(j['discountValue']),
      );
}

// --- Platform admin --------------------------------------------------------------

class AdminOrder {
  final int id;
  final String eventTitle;
  final OrderStatus status;
  final String buyerEmail;
  final int ticketCount;
  final num totalAmount;
  final DateTime? createdAt;
  const AdminOrder(this.id, this.eventTitle, this.status, this.buyerEmail,
      this.ticketCount, this.totalAmount, this.createdAt);

  factory AdminOrder.fromJson(Map<String, dynamic> j) => AdminOrder(
        _num(j['id']).toInt(),
        (j['eventTitle'] ?? '') as String,
        OrderStatus.values.firstWhere(
          (s) => s.name.toUpperCase() == j['status'],
          orElse: () => OrderStatus.pending,
        ),
        (j['buyerEmail'] ?? '') as String,
        _num(j['ticketCount']).toInt(),
        _num(j['totalAmount']),
        _date(j['createdAt']),
      );
}

/// A payment or a refund as the platform admin sees it.
class AdminTransaction {
  final String reference;
  final String status; // SUCCEEDED, FAILED, PENDING (refunds)
  final num amount;
  final String provider;
  final int? orderId;
  final String eventTitle;
  final String buyerEmail;
  final String? reason;
  final String? failureReason;
  final DateTime? createdAt;
  const AdminTransaction({
    required this.reference,
    required this.status,
    required this.amount,
    this.provider = '',
    this.orderId,
    this.eventTitle = '',
    this.buyerEmail = '',
    this.reason,
    this.failureReason,
    this.createdAt,
  });

  factory AdminTransaction.fromJson(Map<String, dynamic> j) => AdminTransaction(
        reference: (j['reference'] ?? '') as String,
        status: (j['status'] ?? '') as String,
        amount: _num(j['amount']),
        provider: (j['provider'] ?? '') as String,
        orderId: j['orderId'] == null ? null : _num(j['orderId']).toInt(),
        eventTitle: (j['eventTitle'] ?? '') as String,
        buyerEmail: (j['buyerEmail'] ?? '') as String,
        reason: j['reason'] as String?,
        failureReason: j['failureReason'] as String?,
        createdAt: _date(j['createdAt']),
      );
}

/// An attendee's complaint about an event.
class EventReport {
  final int id;
  final int eventId;
  final String eventTitle;
  final bool eventSuspended;
  final String reporterEmail;
  final String reason;
  final String message;
  final String status; // OPEN, DISMISSED, ACTIONED
  final String? resolutionNote;
  final DateTime? createdAt;
  const EventReport({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    this.eventSuspended = false,
    this.reporterEmail = '',
    required this.reason,
    this.message = '',
    required this.status,
    this.resolutionNote,
    this.createdAt,
  });

  factory EventReport.fromJson(Map<String, dynamic> j) => EventReport(
        id: _num(j['id']).toInt(),
        eventId: _num(j['eventId']).toInt(),
        eventTitle: (j['eventTitle'] ?? '') as String,
        eventSuspended: (j['eventSuspended'] ?? false) as bool,
        reporterEmail: (j['reporterEmail'] ?? '') as String,
        reason: (j['reason'] ?? 'OTHER') as String,
        message: (j['message'] ?? '') as String,
        status: (j['status'] ?? 'OPEN') as String,
        resolutionNote: j['resolutionNote'] as String?,
        createdAt: _date(j['createdAt']),
      );
}

class PlatformSettings {
  final num activationFeeKzt;
  final num processingFeePercent;
  const PlatformSettings(this.activationFeeKzt, this.processingFeePercent);

  factory PlatformSettings.fromJson(Map<String, dynamic> j) => PlatformSettings(
        _num(j['activationFeeKzt']),
        _num(j['processingFeePercent']),
      );
}
