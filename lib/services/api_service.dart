import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/models.dart';

/// Switch to false once the backend is ready.
const bool kUseMockApi = true;

/// Backend base URL (Android emulator -> host machine is 10.0.2.2).
const String kBaseUrl = 'http://10.0.2.2:8000/api/mobile';

/// Single global instance used by all screens.
final CheckInApi api = kUseMockApi ? MockCheckInApi() : HttpCheckInApi();

abstract class CheckInApi {
  String? token;

  Future<String> login(String email, String password);
  Future<List<EventInfo>> getAssignedEvents();
  Future<EventStats> getStats(String eventId);
  Future<ScanResult> checkInByQr(String eventId, String qrPayload);
  Future<List<Attendee>> searchAttendees(String eventId, String query);
  Future<ScanResult> checkInByTicketId(String eventId, String ticketId);
  Future<void> undoCheckIn(String eventId, String ticketId);
}

// ---------------------------------------------------------------------------
// Mock implementation (in-memory) so the whole UI can be demoed without backend
// ---------------------------------------------------------------------------
class MockCheckInApi extends CheckInApi {
  final _events = const [
    EventInfo(
      id: 'e1',
      title: 'Тестовое мероприятие BiletFlow',
      subtitle: 'Астана • 2026',
    ),
    EventInfo(
      id: 'e2',
      title: 'Студенческий концерт',
      subtitle: 'Алматы • 2026',
      canUndo: false,
    ),
  ];

  late final Map<String, List<Attendee>> _data = {
    'e1': _seed(),
    'e2': _seed(),
  };

  List<Attendee> _seed() => [
        const Attendee(ticketId: 'T-1001', name: 'Айгерим Бекова', email: 'aigerim@mail.kz', ticketType: 'Стандарт', status: TicketStatus.valid),
        const Attendee(ticketId: 'T-1002', name: 'Даулет Сериков', email: 'daulet@mail.kz', ticketType: 'VIP', seat: 'Секция A, ряд 1, место 5', status: TicketStatus.valid),
        const Attendee(ticketId: 'T-1003', name: 'Мария Иванова', email: 'maria@mail.ru', ticketType: 'Стандарт', status: TicketStatus.valid),
        Attendee(ticketId: 'T-1004', name: 'Ерлан Нурланов', email: 'erlan@gmail.com', ticketType: 'Стандарт', status: TicketStatus.checkedIn, checkedInAt: DateTime.now().subtract(const Duration(minutes: 20))),
        const Attendee(ticketId: 'T-1005', name: 'Алия Касымова', email: 'aliya@mail.kz', ticketType: 'Стандарт', status: TicketStatus.cancelled),
        const Attendee(ticketId: 'T-1006', name: 'Тимур Оспанов', email: 'timur@mail.kz', ticketType: 'VIP', status: TicketStatus.refunded),
      ];

  Future<void> _delay() => Future.delayed(const Duration(milliseconds: 400));

  @override
  Future<String> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 700));
    if (!email.contains('@') || password.length < 4) {
      throw ApiException('Неверный email или пароль');
    }
    return 'mock-token';
  }

  @override
  Future<List<EventInfo>> getAssignedEvents() async {
    await _delay();
    return _events;
  }

  @override
  Future<EventStats> getStats(String eventId) async {
    final list = _data[eventId] ?? [];
    final active = list.where((a) =>
        a.status == TicketStatus.valid || a.status == TicketStatus.checkedIn);
    return EventStats(
      list.where((a) => a.status == TicketStatus.checkedIn).length,
      active.length,
    );
  }

  @override
  Future<ScanResult> checkInByQr(String eventId, String qrPayload) async {
    await _delay();
    final id = qrPayload.substring(QrPayload.prefix.length);
    return _doCheckIn(eventId, id);
  }

  @override
  Future<ScanResult> checkInByTicketId(String eventId, String ticketId) async {
    await _delay();
    return _doCheckIn(eventId, ticketId);
  }

  ScanResult _doCheckIn(String eventId, String ticketId) {
    final list = _data[eventId]!;
    final i = list.indexWhere((a) => a.ticketId == ticketId);
    if (i < 0) return const ScanResult(ScanOutcome.invalid);
    final a = list[i];
    switch (a.status) {
      case TicketStatus.cancelled:
        return ScanResult(ScanOutcome.cancelled, attendee: a);
      case TicketStatus.refunded:
        return ScanResult(ScanOutcome.refunded, attendee: a);
      case TicketStatus.checkedIn:
        return ScanResult(ScanOutcome.alreadyUsed, attendee: a);
      case TicketStatus.valid:
        final updated =
            a.copyWith(status: TicketStatus.checkedIn, checkedInAt: DateTime.now());
        list[i] = updated;
        return ScanResult(ScanOutcome.success, attendee: updated);
    }
  }

  @override
  Future<List<Attendee>> searchAttendees(String eventId, String query) async {
    await _delay();
    final q = query.trim().toLowerCase();
    final list = _data[eventId] ?? [];
    if (q.isEmpty) return List.of(list);
    return list
        .where((a) =>
            a.name.toLowerCase().contains(q) ||
            a.email.toLowerCase().contains(q) ||
            a.ticketId.toLowerCase().contains(q))
        .toList();
  }

  @override
  Future<void> undoCheckIn(String eventId, String ticketId) async {
    await _delay();
    final list = _data[eventId]!;
    final i = list.indexWhere((a) => a.ticketId == ticketId);
    if (i >= 0 && list[i].status == TicketStatus.checkedIn) {
      list[i] = list[i].copyWith(status: TicketStatus.valid);
    }
  }
}

// ---------------------------------------------------------------------------
// Real HTTP implementation. Align paths/JSON with the backend API contract.
// ---------------------------------------------------------------------------
class HttpCheckInApi extends CheckInApi {
  final _client = http.Client();
  static const _timeout = Duration(seconds: 8);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> _send(Future<http.Response> Function() call) async {
    try {
      final res = await call().timeout(_timeout);
      if (res.statusCode == 401) {
        throw ApiException('Сессия истекла. Войдите снова.', unauthorized: true);
      }
      final body = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode >= 400) {
        throw ApiException(
            (body is Map ? body['message'] : null)?.toString() ?? 'Ошибка сервера (${res.statusCode})');
      }
      return body;
    } on TimeoutException {
      throw ApiException('Нет ответа от сервера. Проверьте интернет.');
    } on http.ClientException {
      throw ApiException('Нет соединения с сервером.');
    }
  }

  @override
  Future<String> login(String email, String password) async {
    final b = await _send(() => _client.post(Uri.parse('$kBaseUrl/auth/login'),
        headers: _headers, body: jsonEncode({'email': email, 'password': password})));
    return b['token'] as String;
  }

  @override
  Future<List<EventInfo>> getAssignedEvents() async {
    final b = await _send(() => _client.get(Uri.parse('$kBaseUrl/events'), headers: _headers));
    return (b as List).map((e) => EventInfo.fromJson(e)).toList();
  }

  @override
  Future<EventStats> getStats(String eventId) async {
    final b = await _send(
        () => _client.get(Uri.parse('$kBaseUrl/events/$eventId/stats'), headers: _headers));
    return EventStats.fromJson(b);
  }

  ScanResult _parseScan(dynamic b) {
    final outcome = ScanOutcome.values.firstWhere(
      (o) => o.name == b['outcome'],
      orElse: () => ScanOutcome.error,
    );
    return ScanResult(
      outcome,
      attendee: b['attendee'] != null ? Attendee.fromJson(b['attendee']) : null,
      message: b['message'] as String?,
    );
  }

  @override
  Future<ScanResult> checkInByQr(String eventId, String qrPayload) async {
    final b = await _send(() => _client.post(
        Uri.parse('$kBaseUrl/events/$eventId/check-in'),
        headers: _headers,
        body: jsonEncode({'qr': qrPayload})));
    return _parseScan(b);
  }

  @override
  Future<ScanResult> checkInByTicketId(String eventId, String ticketId) async {
    final b = await _send(() => _client.post(
        Uri.parse('$kBaseUrl/events/$eventId/check-in'),
        headers: _headers,
        body: jsonEncode({'ticketId': ticketId})));
    return _parseScan(b);
  }

  @override
  Future<List<Attendee>> searchAttendees(String eventId, String query) async {
    final uri = Uri.parse('$kBaseUrl/events/$eventId/attendees')
        .replace(queryParameters: {'q': query});
    final b = await _send(() => _client.get(uri, headers: _headers));
    return (b as List).map((e) => Attendee.fromJson(e)).toList();
  }

  @override
  Future<void> undoCheckIn(String eventId, String ticketId) async {
    await _send(() => _client.delete(
        Uri.parse('$kBaseUrl/events/$eventId/check-in/$ticketId'),
        headers: _headers));
  }
}
