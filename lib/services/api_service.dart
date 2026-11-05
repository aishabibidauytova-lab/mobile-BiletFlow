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
  final _client = http.Client();
  static const _timeout = Duration(seconds: 10);

  String? token;

  /// Called when the server rejects the token (401), e.g. to show the login screen.
  void Function()? onUnauthorized;

  Map<String, String> get authHeaders =>
      {if (token != null) 'Authorization': 'Bearer $token'};

  Map<String, String> get _headers =>
      {'Content-Type': 'application/json', ...authHeaders};

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$kBaseUrl$path').replace(queryParameters: query);

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
            _message(body) ?? tr('api.server', {'code': res.statusCode}));
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

  Future<Order> createOrder(int eventId, Map<int, int> quantities) async {
    final b = await _post('/orders', {
      'eventId': eventId,
      'items': [
        for (final e in quantities.entries)
          if (e.value > 0) {'ticketTypeId': e.key, 'quantity': e.value},
      ],
    });
    return Order.fromJson(b);
  }

  /// Simulated payment (SRS 3.2: no real money moves in the academic MVP).
  Future<Order> payOrder(int orderId) async =>
      Order.fromJson(await _post('/orders/$orderId/pay'));

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
}
