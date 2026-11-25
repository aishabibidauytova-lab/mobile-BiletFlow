import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

import '../l10n/l10n.dart';
import '../models/models.dart';

/// Backend base URL. API docs: https://biletflow.duckdns.org/swagger-ui/index.html
const String kBaseUrl = 'https://biletflow.duckdns.org/api';

/// Single global instance used by all screens.
final BiletFlowApi api = BiletFlowApi();

class BiletFlowApi {
  final http.Client _client;
  BiletFlowApi({http.Client? client}) : _client = client ?? http.Client();
  static const _timeout = Duration(seconds: 10);

  String? token;

  /// Called when the server rejects the token (401), e.g. to show the login screen.
  void Function()? onUnauthorized;

  Map<String, String> get authHeaders =>
      {if (token != null) 'Authorization': 'Bearer $token'};

  Map<String, String> get _headers =>
      {'Content-Type': 'application/json', ...authHeaders};

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$kBaseUrl$path').replace(
          queryParameters: query == null || query.isEmpty ? null : query);

  Future<dynamic> _send(Future<http.Response> Function() call) async {
    try {
      final res = await call().timeout(_timeout);
      final body = res.body.isEmpty ? null : _tryJson(utf8.decode(res.bodyBytes));
      if (res.statusCode == 401) {
        if (token != null) onUnauthorized?.call();
        throw ApiException(
            _message(body) ?? tr('api.sessionExpired'),
            unauthorized: true);
      }
      if (res.statusCode == 403) {
        throw ApiException(_message(body) ?? tr('api.forbidden'));
      }
      if (res.statusCode >= 400) {
        throw ApiException(
            _message(body) ?? tr('api.server', {'code': res.statusCode}),
            status: res.statusCode);
      }
      return body;
    } on TimeoutException {
      throw ApiException(tr('api.timeout'));
    } on http.ClientException {
      throw ApiException(tr('api.noConnection'));
    }
  }

  static dynamic _tryJson(String s) {
    try {
      return jsonDecode(s);
    } on FormatException {
      return s;
    }
  }

  static String? _message(dynamic body) {
    if (body is Map) {
      final m = body['message'] ?? body['error'] ?? body['detail'];
      if (m != null && '$m'.isNotEmpty) return '$m';
    }
    return null;
  }

  Future<dynamic> _get(String path, [Map<String, String>? q]) =>
      _send(() => _client.get(_uri(path, q), headers: _headers));

  Future<dynamic> _put(String path, Object body) => _send(
      () => _client.put(_uri(path), headers: _headers, body: jsonEncode(body)));

  Future<dynamic> _delete(String path) =>
      _send(() => _client.delete(_uri(path), headers: _headers));

  Future<dynamic> _post(String path, [Object? body]) => _send(() => _client.post(
      _uri(path),
      headers: _headers,
      body: body == null ? null : jsonEncode(body)));

  static const _pageAll = {'size': '100'};

  // --- Auth -----------------------------------------------------------------

  Future<(String, AppUser)> login(String email, String password) async {
    final b = await _post('/auth/login', {'email': email, 'password': password});
    return (b['accessToken'] as String, AppUser.fromJson(b['user']));
  }

  Future<(String, AppUser)> register(String email, String password) async {
    final b =
        await _post('/auth/register', {'email': email, 'password': password});
    return (b['accessToken'] as String, AppUser.fromJson(b['user']));
  }

  Future<AppUser> me() async => AppUser.fromJson(await _get('/users/me'));

  // --- Attendee: events, orders, tickets ------------------------------------

  Future<List<EventInfo>> getEvents() async {
    final b = await _get('/events', {..._pageAll, 'sort': 'startTime'});
    return PageResult.fromJson(b, EventInfo.fromJson).items;
  }

  Future<EventInfo> getEvent(int id) async =>
      EventInfo.fromJson(await _get('/events/$id'));

  Future<List<TicketType>> getTicketTypes(int eventId) async {
    final b = await _get('/events/$eventId/ticket-types') as List;
    return b.map((e) => TicketType.fromJson(e)).where((t) => !t.hidden).toList();
  }

  static List<Map<String, int>> _items(Map<int, int> quantities) => [
        for (final e in quantities.entries)
          if (e.value > 0) {'ticketTypeId': e.key, 'quantity': e.value},
      ];

  /// [quantities] are tickets sold by count; [seatIds] are chosen seats.
  Future<Order> createOrder(int eventId, Map<int, int> quantities,
      {List<int> seatIds = const [],
      String? attendeeName,
      String? promoCode}) async {
    final b = await _post('/orders', {
      'eventId': eventId,
      'items': _items(quantities),
      if (seatIds.isNotEmpty) 'seatIds': seatIds,
      if (attendeeName != null && attendeeName.isNotEmpty) 'attendeeName': attendeeName,
      if (promoCode != null && promoCode.isNotEmpty) 'promoCode': promoCode,
    });
    return Order.fromJson(b);
  }

  /// Price preview with the promo code applied (the server calculates discounts).
  Future<OrderQuote> quoteOrder(int eventId, Map<int, int> quantities,
          {List<int> seatIds = const [], String? promoCode}) async =>
      OrderQuote.fromJson(await _post('/orders/quote', {
        'eventId': eventId,
        'items': _items(quantities),
        if (seatIds.isNotEmpty) 'seatIds': seatIds,
        if (promoCode != null && promoCode.isNotEmpty) 'promoCode': promoCode,
      }));

  Future<Order> startPayment(Order order, {
    required Future<void> Function(Map<String, dynamic>) openBank,
    required void Function() onSimulation,
  }) async {
    if (order.totalAmount == 0) return payOrder(order.id);
    final session = await openPaymentSession(order.id);
    switch (session['provider']) {
      case 'SIMULATED':
        onSimulation();
        return payOrder(order.id);
      case 'HALYK':
        await openBank(session);
        return checkPayment(order.id);
      default:
        throw ApiException(tr('bank.invalid'));
    }
  }

  Future<Map<String, dynamic>> openPaymentSession(int id) async =>
      await _post('/orders/$id/payment-session') as Map<String, dynamic>;

  Future<Order> payOrder(int id) async =>
      Order.fromJson(await _post('/orders/$id/pay'));

  Future<Order> refundOrder(int id, String reason) async =>
      Order.fromJson(await _post('/orders/$id/refund', {
        if (reason.trim().isNotEmpty) 'reason': reason.trim(),
      }));

  Future<List<Map<String, dynamic>>> getRefunds(int id) async =>
      (await _get('/orders/$id/refunds') as List).cast<Map<String, dynamic>>();

  /// Asks the payment provider for the latest status of the order's payment.
  Future<Order> checkPayment(int orderId) async =>
      Order.fromJson(await _post('/orders/$orderId/payment-check'));

  Future<List<Payment>> getPayments(int orderId) async {
    final b = await _get('/orders/$orderId/payments') as List;
    return b.map((e) => Payment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Order> cancelOrder(int orderId) async =>
      Order.fromJson(await _post('/orders/$orderId/cancel'));

  Future<Order> getOrder(int orderId) async =>
      Order.fromJson(await _get('/orders/$orderId'));

  Future<List<Order>> getMyOrders() async {
    final b = await _get('/orders', {..._pageAll, 'sort': 'createdAt,desc'});
    return PageResult.fromJson(b, Order.fromJson).items;
  }

  Future<List<Ticket>> getMyTickets() async {
    final b = await _get('/tickets', _pageAll);
    return PageResult.fromJson(b, Ticket.fromJson).items;
  }

  /// Server-generated QR image (PNG) for a ticket.
  Uri ticketQrUri(int ticketId) => _uri('/tickets/$ticketId/qr');

  /// Print-ready PDF of a ticket (SRS 4.7).
  Future<List<int>> getTicketPdf(int ticketId) async {
    final bytes = await _getBytes('/tickets/$ticketId/pdf');
    if (bytes.length < 5 || ascii.decode(bytes.take(5).toList(), allowInvalid: true) != '%PDF-') {
      throw ApiException(tr('ticket.invalidPdf'));
    }
    return bytes;
  }

  Future<List<int>> _getBytes(String path, [Map<String, String>? query]) async {
    try {
      final res = await _client
          .get(_uri(path, query), headers: authHeaders)
          .timeout(const Duration(seconds: 30));
      if (res.statusCode >= 400) {
        final body = _tryJson(utf8.decode(res.bodyBytes, allowMalformed: true));
        if (res.statusCode == 401 && token != null) onUnauthorized?.call();
        throw ApiException(
            _message(body) ?? tr('api.server', {'code': res.statusCode}),
            unauthorized: res.statusCode == 401);
      }
      return res.bodyBytes;
    } on TimeoutException {
      throw ApiException(tr('api.timeout'));
    } on http.ClientException {
      throw ApiException(tr('api.noConnection'));
    }
  }

  // --- Event Admin: check-in ------------------------------------------------

  Future<List<EventInfo>> getAssignedEvents() async {
    final b = await _get('/check-in/events', _pageAll);
    return PageResult.fromJson(b, EventInfo.fromJson).items;
  }

  Future<EventStats> getStats(int eventId) async =>
      EventStats.fromJson(await _get('/check-in/events/$eventId/stats'));

  Future<ScanResult> checkIn(int eventId, String code) async => ScanResult.fromJson(
      await _post('/check-in/events/$eventId/scan', {'code': code}));

  Future<List<Ticket>> searchAttendees(int eventId, String query) async {
    final b = await _get('/check-in/events/$eventId/attendees',
        {..._pageAll, if (query.trim().isNotEmpty) 'q': query.trim()});
    return PageResult.fromJson(b, Ticket.fromJson).items;
  }

  Future<Ticket> undoCheckIn(int eventId, int ticketId) async => Ticket.fromJson(
      await _post('/check-in/events/$eventId/tickets/$ticketId/undo'));

  // --- Account ----------------------------------------------------------------

  /// Updates the signed-in user's email and/or password (null = unchanged).
  Future<AppUser> updateCredentials({String? email, String? password}) async =>
      AppUser.fromJson(await _put('/users/me/credentials', {
        'email': ?email,
        'password': ?password,
      }));

  Future<void> deleteMyAccount() async => _delete('/users/me');

  // --- Organizer profile -----------------------------------------------------

  Future<OrganizerProfile> getOrganizerProfile() async =>
      OrganizerProfile.fromJson(await _get('/organizers/profile'));

  /// Turns an attendee into an organizer. Returns the new token (role changed).
  Future<String> becomeOrganizer(String contactInformation) async {
    final b = await _post(
        '/organizers/profile', {'contactInformation': contactInformation});
    return b['accessToken'] as String;
  }

  // --- Organizer: events -----------------------------------------------------

  Future<List<EventInfo>> getMyEvents(int organizerId) async {
    final b = await _get('/events/organizer/$organizerId',
        {..._pageAll, 'sort': 'startTime,desc'});
    return PageResult.fromJson(b, EventInfo.fromJson).items;
  }

  Future<EventInfo> createEvent(Map<String, dynamic> body) async =>
      EventInfo.fromJson(await _post('/events', body));

  Future<EventInfo> updateEvent(int id, Map<String, dynamic> body) async =>
      EventInfo.fromJson(await _put('/events/$id', body));

  Future<EventInfo> publishEvent(int id) async =>
      EventInfo.fromJson(await _post('/events/$id/publish'));

  Future<EventInfo> unpublishEvent(int id) async =>
      EventInfo.fromJson(await _post('/events/$id/unpublish'));

  Future<EventInfo> cancelEvent(int id) async =>
      EventInfo.fromJson(await _post('/events/$id/cancel'));

  Future<EventInfo> duplicateEvent(int id) async =>
      EventInfo.fromJson(await _post('/events/$id/duplicate'));

  /// Uploads a poster (JPEG/PNG/WebP, up to 5 MB).
  Future<EventInfo> uploadPoster(
      int eventId, List<int> bytes, String filename, String mime) async {
    try {
      final req = http.MultipartRequest('POST', _uri('/events/$eventId/poster'))
        ..headers.addAll(authHeaders)
        ..files.add(http.MultipartFile.fromBytes('file', bytes,
            filename: filename, contentType: MediaType.parse(mime)));
      final streamed = await _client.send(req).timeout(const Duration(seconds: 60));
      final res = await http.Response.fromStream(streamed);
      final body = res.body.isEmpty ? null : _tryJson(utf8.decode(res.bodyBytes));
      if (res.statusCode == 413) throw ApiException(tr('poster.tooBig'));
      if (res.statusCode >= 400) {
        throw ApiException(
            _message(body) ?? tr('api.server', {'code': res.statusCode}));
      }
      return EventInfo.fromJson(body as Map<String, dynamic>);
    } on TimeoutException {
      throw ApiException(tr('api.timeout'));
    } on http.ClientException {
      throw ApiException(tr('api.noConnection'));
    }
  }

  Future<void> deletePoster(int eventId) async => _delete('/events/$eventId/poster');

  // --- Organizer: venues, ticket types, staff --------------------------------

  Future<List<Venue>> getVenues() async {
    final b = await _get('/venues', _pageAll);
    return PageResult.fromJson(b, Venue.fromJson).items;
  }

  Future<Venue> createVenue(String name, String address, int capacity) async =>
      Venue.fromJson(await _post('/venues',
          {'name': name, 'address': address, 'capacity': capacity}));

  /// All ticket types of an event, including hidden ones (owner view).
  Future<List<TicketType>> getAllTicketTypes(int eventId) async {
    final b = await _get('/events/$eventId/ticket-types') as List;
    return b.map((e) => TicketType.fromJson(e)).toList();
  }

  Future<TicketType> createTicketType(int eventId, Map<String, dynamic> body) async =>
      TicketType.fromJson(await _post('/events/$eventId/ticket-types', body));

  Future<TicketType> updateTicketType(int id, Map<String, dynamic> body) async =>
      TicketType.fromJson(await _put('/ticket-types/$id', body));

  Future<TicketType> hideTicketType(int id) async =>
      TicketType.fromJson(await _post('/ticket-types/$id/hide'));

  Future<TicketType> unhideTicketType(int id) async =>
      TicketType.fromJson(await _post('/ticket-types/$id/unhide'));

  Future<List<StaffMember>> getStaff(int eventId) async {
    final b = await _get('/events/$eventId/staff', _pageAll);
    final list = b is Map ? (b['content'] as List? ?? []) : (b as List);
    return list.map((e) => StaffMember.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<StaffMember> assignStaff(int eventId, String email) async =>
      StaffMember.fromJson(await _post('/events/$eventId/staff', {'email': email}));

  Future<void> removeStaff(int eventId, int userId) async =>
      _delete('/events/$eventId/staff/$userId');

  // --- Platform admin ----------------------------------------------------------

  Future<List<UserAccount>> getUsers() async {
    final b = await _get('/users', {..._pageAll, 'sort': 'createdAt,desc'});
    return PageResult.fromJson(b, UserAccount.fromJson).items;
  }

  /// Admin: change another user's email and/or password (null = unchanged).
  Future<UserAccount> updateUser(int id, {String? email, String? password}) async =>
      UserAccount.fromJson(await _put('/users/$id', {
        'email': ?email,
        'password': ?password,
      }));

  Future<void> deleteUser(int id) async => _delete('/users/$id');

  /// Roles: ATTENDEE, ORGANIZER, EVENT_ADMIN, PLATFORM_ADMIN.
  Future<UserAccount> changeRole(int id, String role) async =>
      UserAccount.fromJson(await _put('/users/$id/role', {'role': role}));

  Future<List<VerificationRequest>> getVerificationRequests() async {
    final b = await _get('/organizers/verification-requests', _pageAll);
    return PageResult.fromJson(b, VerificationRequest.fromJson).items;
  }

  Future<void> reviewOrganizer(int profileId, bool approved, {String? note}) =>
      _post('/organizers/$profileId/verification', {
        'approved': approved,
        if (note != null && note.isNotEmpty) 'note': note,
      });

  /// Admin: paid-sales activations, optionally filtered by status.
  Future<List<Activation>> getActivations({String? status}) async {
    final b = await _get('/admin/paid-sales-activations',
        {..._pageAll, 'status': ?status});
    return PageResult.fromJson(b, Activation.fromJson).items;
  }

  Future<Activation> suspendPaidSales(int eventId, String reason) async =>
      Activation.fromJson(await _post(
          '/events/$eventId/activation/suspend', {'reason': reason}));

  Future<Activation> unsuspendPaidSales(int eventId) async =>
      Activation.fromJson(await _post('/events/$eventId/activation/unsuspend'));

  /// Admin: stop all sales of a suspicious event (SRS 4.12).
  Future<EventInfo> suspendEvent(int eventId, String reason) async =>
      EventInfo.fromJson(await _post('/events/$eventId/suspend', {'reason': reason}));

  Future<EventInfo> unsuspendEvent(int eventId) async =>
      EventInfo.fromJson(await _post('/events/$eventId/unsuspend'));

  // --- Account recovery and email verification ------------------------------------

  Future<void> forgotPassword(String email) =>
      _post('/auth/forgot-password', {'email': email});

  Future<void> resetPassword(String token, String newPassword) =>
      _post('/auth/reset-password', {'token': token, 'newPassword': newPassword});

  Future<void> verifyEmail(String token) =>
      _post('/auth/verify-email', {'token': token});

  Future<void> resendVerification(String email) =>
      _post('/auth/resend-verification', {'email': email});

  // --- Notifications ---------------------------------------------------------------

  Future<List<AppNotification>> getNotifications() async {
    final b = await _get('/notifications', {..._pageAll, 'sort': 'createdAt,desc'});
    return PageResult.fromJson(b, AppNotification.fromJson).items;
  }

  Future<int> getUnreadCount() async {
    final b = await _get('/notifications/unread-count');
    if (b is Map && b.isNotEmpty) return _toInt(b['unread'] ?? b.values.first);
    return _toInt(b);
  }

  static int _toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  Future<void> markNotificationRead(int id) => _post('/notifications/$id/read');

  Future<void> markAllNotificationsRead() => _post('/notifications/read-all');

  // --- Support --------------------------------------------------------------------

  Future<List<SupportCase>> getSupportCases({String? status, bool? escalated}) async {
    final b = await _get('/support/cases', {
      ..._pageAll,
      'sort': 'updatedAt,desc',
      'status': ?status,
      if (escalated != null) 'escalated': '$escalated',
    });
    return PageResult.fromJson(b, SupportCase.fromJson).items;
  }

  Future<SupportCaseDetail> getSupportCase(int id) async =>
      SupportCaseDetail.fromJson(await _get('/support/cases/$id'));

  /// [type]: ATTENDEE (to the event organizer) or PLATFORM (to BiletFlow staff).
  Future<SupportCaseDetail> openSupportCase({
    required String type,
    required String category,
    required String subject,
    required String message,
    int? eventId,
    int? orderId,
    int? ticketId,
  }) async =>
      SupportCaseDetail.fromJson(await _post('/support/cases', {
        'type': type,
        'category': category,
        'subject': subject,
        'message': message,
        'eventId': ?eventId,
        'orderId': ?orderId,
        'ticketId': ?ticketId,
      }));

  Future<SupportCaseDetail> replyToCase(int id, String body) async =>
      SupportCaseDetail.fromJson(await _post('/support/cases/$id/messages', {'body': body}));

  Future<SupportCaseDetail> setCaseStatus(int id, String status) async =>
      SupportCaseDetail.fromJson(await _post('/support/cases/$id/status', {'status': status}));

  Future<SupportCaseDetail> assignCase(int id, String email) async =>
      SupportCaseDetail.fromJson(await _post('/support/cases/$id/assign', {'email': email}));

  Future<SupportCaseDetail> escalateCase(int id) async =>
      SupportCaseDetail.fromJson(await _post('/support/cases/$id/escalate'));

  // --- Organizer: promo campaigns ----------------------------------------------------

  Future<List<Campaign>> getCampaigns(int eventId) async {
    final b = await _get('/events/$eventId/campaigns') as List;
    return b.map((e) => Campaign.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Campaign> createCampaign(int eventId, Map<String, dynamic> body) async =>
      Campaign.fromJson(await _post('/events/$eventId/campaigns', body));

  Future<Campaign> setCampaignEnabled(int eventId, int id, bool enabled) async =>
      Campaign.fromJson(await _post(
          '/events/$eventId/campaigns/$id/${enabled ? 'enable' : 'disable'}'));

  /// Server-generated Campaign QR image (PNG).
  Uri campaignQrUri(int eventId, int id) => _uri('/events/$eventId/campaigns/$id/qr');

  // --- Organizer: paid sales activation and payout ----------------------------------

  Future<Activation> getActivation(int eventId) async =>
      Activation.fromJson(await _get('/events/$eventId/activation'));

  /// [step]: pay-fee, accept-terms or activate.
  Future<Activation> activationStep(int eventId, String step) async =>
      Activation.fromJson(await _post('/events/$eventId/activation/$step'));

  Future<PayoutAccount?> getPayoutAccount() async {
    final b = await _get('/organizers/profile/payout-account');
    return b is Map<String, dynamic> && b.isNotEmpty ? PayoutAccount.fromJson(b) : null;
  }

  Future<PayoutAccount> savePayoutAccount(
          String bankName, String accountHolder, String iban) async =>
      PayoutAccount.fromJson(await _put('/organizers/profile/payout-account', {
        'bankName': bankName,
        'accountHolder': accountHolder,
        'iban': iban,
      }));

  Future<OrganizerProfile> requestVerification() async =>
      OrganizerProfile.fromJson(await _post('/organizers/profile/verification'));

  // --- Organizer: event phases, attendance, history -----------------------------

  /// The signed-in organizer's events. [phase]: UPCOMING, ACTIVE, COMPLETED
  /// or CANCELLED (null = all).
  Future<List<EventInfo>> getOrganizerEvents({String? phase}) async {
    final b = await _get('/organizer/events', {..._pageAll, 'phase': ?phase});
    return PageResult.fromJson(b, EventInfo.fromJson).items;
  }

  Future<Attendance> getAttendance(int eventId, {int? ticketTypeId}) async =>
      Attendance.fromJson(await _get('/organizer/events/$eventId/attendance', {
        if (ticketTypeId != null) 'ticketTypeId': '$ticketTypeId',
      }));

  /// Activity timeline of one event (SRS 4.16).
  Future<PageResult<HistoryEntry>> getEventHistory(
    int eventId, {
    DateTime? from,
    DateTime? to,
    String? action,
    String? entityType,
    int page = 0,
  }) async =>
      PageResult.fromJson(
          await _get('/organizer/events/$eventId/history', {
            'page': '$page',
            'size': '50',
            if (from != null) 'from': isoDate(from),
            if (to != null) 'to': isoDate(to),
            'action': ?action,
            'entityType': ?entityType,
          }),
          HistoryEntry.fromJson);

  // --- Campaign links and event reports -----------------------------------------

  /// Resolves a campaign link value, which is either a link token or a promo code.
  Future<PromoPreview> previewPromo(int eventId, String value) async {
    Future<PromoPreview> by(String key) async => PromoPreview.fromJson(
        await _get('/events/$eventId/promo', {key: value}));
    try {
      return await by('token');
    } on ApiException catch (e) {
      if (e.status != 400) rethrow;
      return by('code');
    }
  }

  Future<void> reportEvent(int eventId, String reason, String message) =>
      _post('/events/$eventId/reports', {
        'reason': reason,
        if (message.trim().isNotEmpty) 'message': message.trim(),
      });

  // --- Platform admin: search, monitoring, reports, settings --------------------

  Future<PageResult<T>> _adminSearch<T>(
    String path,
    T Function(Map<String, dynamic>) parse,
    Map<String, String?> filters,
  ) async =>
      PageResult.fromJson(
          await _get('/admin/$path', {
            ..._pageAll,
            for (final f in filters.entries)
              if (f.value != null && f.value!.trim().isNotEmpty)
                f.key: f.value!.trim(),
          }),
          parse);

  Future<PageResult<EventInfo>> searchAdminEvents(
          {String? query, bool? suspended}) =>
      _adminSearch('events', EventInfo.fromJson,
          {'q': query, 'suspended': suspended?.toString()});

  Future<PageResult<AdminOrder>> searchAdminOrders(
          {String? query, String? status}) =>
      _adminSearch(
          'orders', AdminOrder.fromJson, {'q': query, 'status': status});

  Future<PageResult<AdminTransaction>> searchAdminPayments(
          {String? query, String? status}) =>
      _adminSearch('payments', AdminTransaction.fromJson,
          {'q': query, 'status': status});

  Future<PageResult<AdminTransaction>> searchAdminRefunds(
          {String? query, String? status}) =>
      _adminSearch('refunds', AdminTransaction.fromJson,
          {'q': query, 'status': status});

  Future<PageResult<EventReport>> getEventReports({String? status}) =>
      _adminSearch('event-reports', EventReport.fromJson, {'status': status});

  /// [outcome]: DISMISSED or ACTIONED.
  Future<void> reviewEventReport(int id, String outcome, String note) =>
      _post('/admin/event-reports/$id/review', {
        'outcome': outcome,
        if (note.trim().isNotEmpty) 'note': note.trim(),
      });

  Future<PlatformSettings> getPlatformSettings() async =>
      PlatformSettings.fromJson(await _get('/admin/settings'));

  Future<PlatformSettings> savePlatformSettings(
          num activationFee, num processingPercent) async =>
      PlatformSettings.fromJson(await _put('/admin/settings', {
        'activationFeeKzt': activationFee,
        'processingFeePercent': processingPercent,
      }));

  /// CSV report: [kind] is events, payments or payouts.
  Future<List<int>> getReportCsv(String kind, {DateTime? from, DateTime? to}) =>
      _getBytes('/admin/reports/$kind.csv', {
        if (from != null) 'from': isoDate(from),
        if (to != null) 'to': isoDate(to),
      });

  // --- Seat maps (SRS 4.3.1) ----------------------------------------------------

  /// What attendees see.
  Future<SeatMap> getSeatMap(int eventId) async =>
      SeatMap.fromJson(await _get('/events/$eventId/seat-map'));

  Future<List<Seat>> getSectionSeats(int eventId, int sectionId) async {
    final b = await _get('/events/$eventId/seat-map/sections/$sectionId');
    return (b['seats'] as List? ?? [])
        .map((e) => Seat.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Organizer's view of the seating configuration.
  Future<SeatMap> getSeating(int eventId) async =>
      SeatMap.fromJson(await _get('/events/$eventId/seating'));

  Future<void> setSeatingMode(int eventId, {required bool assigned}) =>
      _put('/events/$eventId/seating',
          {'mode': assigned ? 'ASSIGNED' : 'GENERAL_ADMISSION'});

  /// A null [ticketTypeId] takes the section off sale.
  Future<void> assignSection(int eventId, int sectionId, int? ticketTypeId) =>
      _put('/events/$eventId/seating/sections/$sectionId',
          {'ticketTypeId': ticketTypeId});

  Future<void> blockSeats(int eventId, List<int> seatIds, bool blocked) => _put(
      '/events/$eventId/seating/seats',
      {'seatIds': seatIds, 'blocked': blocked});

  Future<List<SeatingLayout>> getSeatingLayouts() async =>
      (await _get('/venues/seating-layouts') as List)
          .map((e) => SeatingLayout.fromJson(e as Map<String, dynamic>))
          .toList();

  /// Admin: gives a venue a seating plan, or removes it (null).
  Future<void> setVenueLayout(int venueId, String? layout) =>
      _put('/venues/$venueId/seating-layout', {'seatingLayout': layout});

  // --- Calendar export (SRS 4.11) -----------------------------------------------

  Future<CalendarLinks> getCalendarLinks(int eventId) async =>
      CalendarLinks.fromJson(await _get('/events/$eventId/calendar'));

  Future<List<int>> getCalendarFile(int eventId) =>
      _getBytes('/events/$eventId/calendar.ics');

  // --- Organizer: sales -----------------------------------------------------------

  Future<SalesSummary> getSalesSummary() async =>
      SalesSummary.fromJson(await _get('/organizer/sales/events'));

  /// [from], [to] and [ticketTypeId] narrow only `salesByDay`; the server
  /// always calculates the totals over the whole event.
  Future<EventSales> getEventSales(int eventId,
          {DateTime? from, DateTime? to, int? ticketTypeId}) async =>
      EventSales.fromJson(await _get('/organizer/events/$eventId/sales', {
        if (from != null) 'from': isoDate(from),
        if (to != null) 'to': isoDate(to),
        if (ticketTypeId != null) 'ticketTypeId': '$ticketTypeId',
      }));

  Future<List<EventOrder>> getEventOrders(int eventId, {String? status, String? query}) async {
    final b = await _get('/organizer/events/$eventId/orders', {
      ..._pageAll,
      'sort': 'createdAt,desc',
      'status': ?status,
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
    });
    return PageResult.fromJson(b, EventOrder.fromJson).items;
  }
}
