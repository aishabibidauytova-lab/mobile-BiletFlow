part of 'models.dart';

// --- Checkout: promo codes and payments ----------------------------------------

class OrderQuote {
  final num subtotal;
  final num discount;
  final num total;
  final String? promoCode;
  const OrderQuote(this.subtotal, this.discount, this.total, this.promoCode);

  factory OrderQuote.fromJson(Map<String, dynamic> j) => OrderQuote(
        _num(j['subtotalAmount']),
        _num(j['discountAmount']),
        _num(j['totalAmount']),
        j['promoCode'] as String?,
      );
}

class Payment {
  final int id;
  final String reference;
  final String status; // SUCCEEDED, FAILED
  final num amount;
  final num processingFee;
  final bool simulated;
  final String provider;
  final String? failureReason;
  final DateTime? createdAt;

  const Payment({
    required this.id,
    required this.reference,
    required this.status,
    required this.amount,
    this.processingFee = 0,
    this.simulated = true,
    this.provider = '',
    this.failureReason,
    this.createdAt,
  });

  bool get succeeded => status == 'SUCCEEDED';

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        id: _num(j['id']).toInt(),
        reference: (j['reference'] ?? '') as String,
        status: (j['status'] ?? '') as String,
        amount: _num(j['amount']),
        processingFee: _num(j['processingFee']),
        simulated: (j['simulated'] ?? true) as bool,
        provider: (j['provider'] ?? '') as String,
        failureReason: j['failureReason'] as String?,
        createdAt: _date(j['createdAt']),
      );
}

/// Promo campaign with its code, campaign link and sales statistics.
class Campaign {
  final int id;
  final int eventId;
  final String name;
  final String code;
  final String campaignUrl;
  final String discountType; // PERCENT, FIXED
  final num discountValue;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final int? maxRedemptions;
  final bool enabled;
  final int redemptions;
  final int remainingRedemptions;
  final int ticketsSold;
  final num grossRevenue;
  final num discountAmount;
  final num netRevenue;

  const Campaign({
    required this.id,
    required this.eventId,
    required this.name,
    required this.code,
    this.campaignUrl = '',
    required this.discountType,
    required this.discountValue,
    this.validFrom,
    this.validUntil,
    this.maxRedemptions,
    this.enabled = true,
    this.redemptions = 0,
    this.remainingRedemptions = 0,
    this.ticketsSold = 0,
    this.grossRevenue = 0,
    this.discountAmount = 0,
    this.netRevenue = 0,
  });

  /// "−20%" or "−1 500 ₸".
  String get discountLabel => discountType == 'PERCENT'
      ? '−${discountValue.round()}%'
      : '−${formatPrice(discountValue)}';

  factory Campaign.fromJson(Map<String, dynamic> j) => Campaign(
        id: _num(j['id']).toInt(),
        eventId: _num(j['eventId']).toInt(),
        name: (j['name'] ?? '') as String,
        code: (j['code'] ?? '') as String,
        campaignUrl: (j['campaignUrl'] ?? '') as String,
        discountType: (j['discountType'] ?? 'PERCENT') as String,
        discountValue: _num(j['discountValue']),
        validFrom: _date(j['validFrom']),
        validUntil: _date(j['validUntil']),
        maxRedemptions:
            j['maxRedemptions'] == null ? null : _num(j['maxRedemptions']).toInt(),
        enabled: (j['enabled'] ?? true) as bool,
        redemptions: _num(j['redemptions']).toInt(),
        remainingRedemptions: _num(j['remainingRedemptions']).toInt(),
        ticketsSold: _num(j['ticketsSold']).toInt(),
        grossRevenue: _num(j['grossRevenue']),
        discountAmount: _num(j['discountAmount']),
        netRevenue: _num(j['netRevenue']),
      );
}

// --- Organizer: paid sales activation, payout -----------------------------------

class ChecklistItem {
  final String key;
  final String label;
  final bool done;
  const ChecklistItem(this.key, this.label, this.done);

  factory ChecklistItem.fromJson(Map<String, dynamic> j) => ChecklistItem(
      (j['key'] ?? '') as String, (j['label'] ?? '') as String, (j['done'] ?? false) as bool);
}

class Activation {
  final int eventId;
  final String eventTitle;
  final String status; // IN_PROGRESS, ACTIVE, SUSPENDED
  final bool simulated;
  final num feeAmount;
  final String? feeReference;
  final DateTime? feePaidAt;
  final DateTime? termsAcceptedAt;
  final DateTime? activatedAt;
  final String? suspensionReason;
  final List<ChecklistItem> checklist;
  final bool readyToActivate;

  const Activation({
    required this.eventId,
    required this.eventTitle,
    required this.status,
    this.simulated = true,
    this.feeAmount = 0,
    this.feeReference,
    this.feePaidAt,
    this.termsAcceptedAt,
    this.activatedAt,
    this.suspensionReason,
    this.checklist = const [],
    this.readyToActivate = false,
  });

  factory Activation.fromJson(Map<String, dynamic> j) => Activation(
        eventId: _num(j['eventId']).toInt(),
        eventTitle: (j['eventTitle'] ?? '') as String,
        status: (j['status'] ?? 'IN_PROGRESS') as String,
        simulated: (j['simulated'] ?? true) as bool,
        feeAmount: _num(j['feeAmount']),
        feeReference: j['feeReference'] as String?,
        feePaidAt: _date(j['feePaidAt']),
        termsAcceptedAt: _date(j['termsAcceptedAt']),
        activatedAt: _date(j['activatedAt']),
        suspensionReason: j['suspensionReason'] as String?,
        checklist: (j['checklist'] as List? ?? [])
            .map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        readyToActivate: (j['readyToActivate'] ?? false) as bool,
      );
}

class PayoutAccount {
  final String bankName;
  final String accountHolder;
  final String ibanLast4;
  final bool simulated;
  const PayoutAccount(this.bankName, this.accountHolder, this.ibanLast4, this.simulated);

  factory PayoutAccount.fromJson(Map<String, dynamic> j) => PayoutAccount(
        (j['bankName'] ?? '') as String,
        (j['accountHolder'] ?? '') as String,
        (j['ibanLast4'] ?? '') as String,
        (j['simulated'] ?? true) as bool,
      );
}

/// Admin: an organizer waiting for identity/payout verification.
class VerificationRequest {
  final int profileId;
  final int userId;
  final String email;
  final String contactInformation;
  final String status;
  const VerificationRequest(
      this.profileId, this.userId, this.email, this.contactInformation, this.status);

  factory VerificationRequest.fromJson(Map<String, dynamic> j) => VerificationRequest(
        _num(j['id']).toInt(),
        _num(j['userId']).toInt(),
        (j['email'] ?? '') as String,
        (j['contactInformation'] ?? '') as String,
        (j['verificationStatus'] ?? '') as String,
      );
}

// --- Organizer: sales -------------------------------------------------------------

class TicketTypeSales {
  final int id;
  final String name;
  final num price;
  final int quantity;
  final int sold;
  final int reserved;
  final int available;
  final num revenue;
  const TicketTypeSales(this.name, this.price, this.quantity, this.sold,
      this.reserved, this.available, this.revenue,
      {this.id = 0});

  factory TicketTypeSales.fromJson(Map<String, dynamic> j) => TicketTypeSales(
        (j['name'] ?? '') as String,
        _num(j['price']),
        _num(j['quantity']).toInt(),
        _num(j['sold']).toInt(),
        _num(j['reserved']).toInt(),
        _num(j['available']).toInt(),
        _num(j['revenue']),
        id: _num(j['ticketTypeId']).toInt(),
      );
}

class DailySales {
  final DateTime? date;
  final int ticketsSold;
  final num revenue;
  const DailySales(this.date, this.ticketsSold, this.revenue);

  factory DailySales.fromJson(Map<String, dynamic> j) =>
      DailySales(_date(j['date']), _num(j['ticketsSold']).toInt(), _num(j['revenue']));
}

/// Sales figures for one event, or the totals across events.
class SalesFigures {
  final num refunds;
  final int paidOrders;
  final int pendingOrders;
  final int ticketsSold;
  final int ticketsReserved;
  final num revenue;
  final num discounts;
  final num netRevenue;
  final num processingFees;
  final num estimatedPayout;

  const SalesFigures({
    this.refunds = 0,
    this.paidOrders = 0,
    this.pendingOrders = 0,
    this.ticketsSold = 0,
    this.ticketsReserved = 0,
    this.revenue = 0,
    this.discounts = 0,
    this.netRevenue = 0,
    this.processingFees = 0,
    this.estimatedPayout = 0,
  });

  factory SalesFigures.fromJson(Map<String, dynamic> j) => SalesFigures(
        refunds: _num(j['refunds']),
        paidOrders: _num(j['paidOrders']).toInt(),
        pendingOrders: _num(j['pendingOrders']).toInt(),
        ticketsSold: _num(j['ticketsSold']).toInt(),
        ticketsReserved: _num(j['ticketsReserved']).toInt(),
        revenue: _num(j['revenue']),
        discounts: _num(j['discounts']),
        netRevenue: _num(j['netRevenue']),
        processingFees: _num(j['processingFees']),
        estimatedPayout: _num(j['estimatedPayout']),
      );
}

class EventSales {
  final int eventId;
  final String eventTitle;
  final DateTime? startTime;
  final int? capacity;
  final SalesFigures figures;
  final List<TicketTypeSales> ticketTypes;
  final List<DailySales> salesByDay;

  const EventSales({
    required this.eventId,
    required this.eventTitle,
    this.startTime,
    this.capacity,
    required this.figures,
    this.ticketTypes = const [],
    this.salesByDay = const [],
  });

  factory EventSales.fromJson(Map<String, dynamic> j) => EventSales(
        eventId: _num(j['eventId']).toInt(),
        eventTitle: (j['eventTitle'] ?? '') as String,
        startTime: _date(j['startTime']),
        capacity: j['capacity'] == null ? null : _num(j['capacity']).toInt(),
        figures: SalesFigures.fromJson(j),
        ticketTypes: (j['ticketTypes'] as List? ?? [])
            .map((e) => TicketTypeSales.fromJson(e as Map<String, dynamic>))
            .toList(),
        salesByDay: (j['salesByDay'] as List? ?? [])
            .map((e) => DailySales.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class SalesSummary {
  final List<EventSales> events;
  final SalesFigures totals;
  const SalesSummary(this.events, this.totals);

  factory SalesSummary.fromJson(Map<String, dynamic> j) => SalesSummary(
        (j['events'] as List? ?? [])
            .map((e) => EventSales.fromJson(e as Map<String, dynamic>))
            .toList(),
        SalesFigures.fromJson((j['totals'] ?? const <String, dynamic>{})
            as Map<String, dynamic>),
      );
}

/// An order as the organizer sees it (with the buyer's email).
class EventOrder {
  final int id;
  final OrderStatus status;
  final String buyerEmail;
  final String? attendeeName;
  final num totalAmount;
  final num discountAmount;
  final String? promoCode;
  final int ticketCount;
  final DateTime? createdAt;

  const EventOrder({
    required this.id,
    required this.status,
    required this.buyerEmail,
    this.attendeeName,
    required this.totalAmount,
    this.discountAmount = 0,
    this.promoCode,
    this.ticketCount = 0,
    this.createdAt,
  });

  factory EventOrder.fromJson(Map<String, dynamic> j) => EventOrder(
        id: _num(j['id']).toInt(),
        status: OrderStatus.values.firstWhere(
          (s) => s.name.toUpperCase() == j['status'],
          orElse: () => OrderStatus.pending,
        ),
        buyerEmail: (j['buyerEmail'] ?? '') as String,
        attendeeName: j['attendeeName'] as String?,
        totalAmount: _num(j['totalAmount']),
        discountAmount: _num(j['discountAmount']),
        promoCode: j['promoCode'] as String?,
        ticketCount: _num(j['ticketCount']).toInt(),
        createdAt: _date(j['createdAt']),
      );
}

// --- Notifications -------------------------------------------------------------------

class AppNotification {
  final int id;
  final String type;
  final String title;
  final String body;
  final int? orderId;
  final DateTime? readAt;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.orderId,
    this.readAt,
    this.createdAt,
  });

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: _num(j['id']).toInt(),
        type: (j['type'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        body: (j['body'] ?? '') as String,
        orderId: j['orderId'] == null ? null : _num(j['orderId']).toInt(),
        readAt: _date(j['readAt']),
        createdAt: _date(j['createdAt']),
      );
}

// --- Support -------------------------------------------------------------------------

const supportCategories = [
  'TICKET_DELIVERY', 'PAYMENT', 'REFUND', 'SEATING', 'EVENT_INFORMATION',
  'CHECK_IN', 'ACCOUNT', 'ACTIVATION', 'TECHNICAL', 'OTHER',
];

const supportStatuses = ['OPEN', 'IN_PROGRESS', 'WAITING_FOR_CUSTOMER', 'RESOLVED'];

class SupportCase {
  final int id;
  final String type; // ATTENDEE, PLATFORM
  final String category;
  final String subject;
  final String status;
  final bool escalated;
  final int requesterId;
  final String requesterEmail;
  final String? assigneeEmail;
  final int? eventId;
  final String? eventTitle;
  final int? orderId;
  final int? ticketId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SupportCase({
    required this.id,
    required this.type,
    required this.category,
    required this.subject,
    required this.status,
    this.escalated = false,
    required this.requesterId,
    this.requesterEmail = '',
    this.assigneeEmail,
    this.eventId,
    this.eventTitle,
    this.orderId,
    this.ticketId,
    this.createdAt,
    this.updatedAt,
  });

  factory SupportCase.fromJson(Map<String, dynamic> j) => SupportCase(
        id: _num(j['id']).toInt(),
        type: (j['type'] ?? 'ATTENDEE') as String,
        category: (j['category'] ?? 'OTHER') as String,
        subject: (j['subject'] ?? '') as String,
        status: (j['status'] ?? 'OPEN') as String,
        escalated: (j['escalated'] ?? false) as bool,
        requesterId: _num(j['requesterId']).toInt(),
        requesterEmail: (j['requesterEmail'] ?? '') as String,
        assigneeEmail: j['assigneeEmail'] as String?,
        eventId: j['eventId'] == null ? null : _num(j['eventId']).toInt(),
        eventTitle: j['eventTitle'] as String?,
        orderId: j['orderId'] == null ? null : _num(j['orderId']).toInt(),
        ticketId: j['ticketId'] == null ? null : _num(j['ticketId']).toInt(),
        createdAt: _date(j['createdAt']),
        updatedAt: _date(j['updatedAt']),
      );
}

class SupportMessage {
  final int id;
  final String authorName;
  final bool fromStaff;
  final String body;
  final DateTime? createdAt;
  const SupportMessage(this.id, this.authorName, this.fromStaff, this.body, this.createdAt);

  factory SupportMessage.fromJson(Map<String, dynamic> j) => SupportMessage(
        _num(j['id']).toInt(),
        (j['authorName'] ?? '') as String,
        (j['fromStaff'] ?? false) as bool,
        (j['body'] ?? '') as String,
        _date(j['createdAt']),
      );
}

class SupportCaseDetail {
  final SupportCase supportCase;
  final List<SupportMessage> messages;
  const SupportCaseDetail(this.supportCase, this.messages);

  factory SupportCaseDetail.fromJson(Map<String, dynamic> j) => SupportCaseDetail(
        SupportCase.fromJson(j['supportCase'] as Map<String, dynamic>),
        (j['messages'] as List? ?? [])
            .map((e) => SupportMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
