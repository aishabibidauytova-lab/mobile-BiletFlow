import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

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
            _message(body) ?? 'Сессия истекла. Войдите снова.',
            unauthorized: true);
      }
      if (res.statusCode == 403) {
        throw ApiException(_message(body) ?? 'Нет доступа.');
      }
      if (res.statusCode >= 400) {
        throw ApiException(
            _message(body) ?? 'Ошибка сервера (${res.statusCode})');
      }
      return body;
    } on TimeoutException {
      throw ApiException('Нет ответа от сервера. Проверьте интернет.');
    } on http.ClientException {
      throw ApiException('Нет соединения с сервером.');
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
}
