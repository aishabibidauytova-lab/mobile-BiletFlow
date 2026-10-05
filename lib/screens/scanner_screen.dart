import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models/models.dart';
import '../../services/api_service.dart';
import 'attendee_search_screen.dart';

class ScannerScreen extends StatefulWidget {
  final EventInfo event;

  const ScannerScreen({super.key, required this.event});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  EventStats _stats = const EventStats(0, 0);
  ScanResult? _result;
  bool _busy = false; // true while a scan is being processed or shown
  bool _undoing = false;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _refreshStats();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refreshStats() async {
    try {
      final s = await api.getStats(widget.event.id);
      if (mounted) setState(() => _stats = s);
    } catch (_) {
      // Keep the previous counter if the refresh fails.
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    final raw = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    _busy = true;
    _dismissTimer?.cancel();

    ScanResult result;
    if (!QrPayload.isAdmissionTicket(raw)) {
      // Campaign QR codes (https links) and random QR codes never grant entry.
      result = ScanResult(
        ScanOutcome.notTicket,
        message: QrPayload.looksLikeLink(raw)
            ? 'Это рекламный QR-код, а не билет.'
            : 'Этот QR-код не является билетом BiletFlow.',
      );
    } else {
      try {
        result = await api.checkInByQr(widget.event.id, raw);
      } on ApiException catch (e) {
        result = ScanResult(ScanOutcome.error, message: e.message);
      } catch (_) {
        result = const ScanResult(ScanOutcome.error,
            message: 'Ошибка проверки. Попробуйте ещё раз.');
      }
    }

    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() => _result = result);
    if (result.outcome == ScanOutcome.success) _refreshStats();
    _dismissTimer = Timer(const Duration(seconds: 4), _dismiss);
  }

  void _dismiss() {
    _dismissTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _result = null;
      _busy = false;
    });
    // Allow re-scanning the same code after the result is dismissed.
    _controller.start();
  }

  Future<void> _undo() async {
    final a = _result?.attendee;
    if (a == null) return;
    _dismissTimer?.cancel();
    setState(() => _undoing = true);
    try {
      await api.undoCheckIn(widget.event.id, a.ticketId);
      await _refreshStats();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Чек-ин отменён')),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _undoing = false);
      _dismiss();
    }
  }

  Future<void> _openSearch() async {
    _dismissTimer?.cancel();
    await _controller.stop();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AttendeeSearchScreen(event: widget.event)),
    );
    await _refreshStats();
    if (!mounted) return;
    setState(() {
      _result = null;
      _busy = false;
    });
    _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    final pct =
        _stats.total == 0 ? 0.0 : _stats.checkedIn / _stats.total;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Поиск участника',
            icon: const Icon(Icons.search),
            onPressed: _openSearch,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Chip(
                label: Text('${_stats.checkedIn} / ${_stats.total}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: Colors.deepPurple.shade50,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: pct, minHeight: 4),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Нет доступа к камере.\nРазрешите доступ в настройках телефона '
                  'или воспользуйтесь поиском участника.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          ),
          // Scan frame + hint
          IgnorePointer(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white70, width: 3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Наведите камеру на QR-код билета',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Torch / camera switch
          Positioned(
            right: 12,
            top: 12,
            child: Column(
              children: [
                _RoundButton(
                  icon: Icons.flash_on,
                  tooltip: 'Фонарик',
                  onTap: () => _controller.toggleTorch(),
                ),
                const SizedBox(height: 8),
                _RoundButton(
                  icon: Icons.cameraswitch,
                  tooltip: 'Сменить камеру',
                  onTap: () => _controller.switchCamera(),
                ),
              ],
            ),
          ),
          if (_result != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _ResultPanel(
                result: _result!,
                canUndo: widget.event.canUndo,
                undoing: _undoing,
                onUndo: _undo,
                onClose: _dismiss,
              ),
            ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _RoundButton(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: Colors.white),
        onPressed: onTap,
      ),
    );
  }
}

/// Visual description for every scan outcome (colour + icon + text, so the
/// result is never conveyed by colour alone).
class _OutcomeStyle {
  final Color color;
  final IconData icon;
  final String title;
  const _OutcomeStyle(this.color, this.icon, this.title);

  static _OutcomeStyle of(ScanOutcome o) {
    switch (o) {
      case ScanOutcome.success:
        return const _OutcomeStyle(
            Color(0xFF2E7D32), Icons.check_circle, 'БИЛЕТ ДЕЙСТВИТЕЛЕН');
      case ScanOutcome.alreadyUsed:
        return const _OutcomeStyle(
            Color(0xFFEF6C00), Icons.warning_amber_rounded, 'УЖЕ ИСПОЛЬЗОВАН');
      case ScanOutcome.cancelled:
        return const _OutcomeStyle(
            Color(0xFFC62828), Icons.cancel, 'БИЛЕТ ОТМЕНЁН');
      case ScanOutcome.refunded:
        return const _OutcomeStyle(
            Color(0xFFC62828), Icons.money_off, 'БИЛЕТ ВОЗВРАЩЁН');
      case ScanOutcome.wrongEvent:
        return const _OutcomeStyle(
            Color(0xFFC62828), Icons.event_busy, 'БИЛЕТ НА ДРУГОЕ СОБЫТИЕ');
      case ScanOutcome.notTicket:
        return const _OutcomeStyle(
            Color(0xFF6A1B9A), Icons.qr_code_2, 'ЭТО НЕ БИЛЕТ');
      case ScanOutcome.invalid:
        return const _OutcomeStyle(
            Color(0xFFC62828), Icons.block, 'НЕДЕЙСТВИТЕЛЬНЫЙ БИЛЕТ');
      case ScanOutcome.error:
        return const _OutcomeStyle(
            Color(0xFF455A64), Icons.error_outline, 'ОШИБКА ПРОВЕРКИ');
    }
  }
}

class _ResultPanel extends StatelessWidget {
  final ScanResult result;
  final bool canUndo;
  final bool undoing;
  final VoidCallback onUndo;
  final VoidCallback onClose;

  const _ResultPanel({
    required this.result,
    required this.canUndo,
    required this.undoing,
    required this.onUndo,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final style = _OutcomeStyle.of(result.outcome);
    final a = result.attendee;
    final isSuccess = result.outcome == ScanOutcome.success;

    String? usedAt;
    if (result.outcome == ScanOutcome.alreadyUsed && a?.checkedInAt != null) {
      final t = a!.checkedInAt!.toLocal();
      usedAt =
          'Чек-ин: ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }

    return Material(
      color: style.color,
      elevation: 12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(style.icon, color: Colors.white, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(style.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: onClose,
                  ),
                ],
              ),
              if (a != null) ...[
                const SizedBox(height: 8),
                Text(a.name,
                    style: const TextStyle(color: Colors.white, fontSize: 18)),
                Text(
                  [
                    a.ticketType,
                    if (a.seat != null) a.seat!,
                    a.ticketId,
                  ].join(' • '),
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
              if (usedAt != null)
                Text(usedAt, style: const TextStyle(color: Colors.white70)),
              if (result.message != null) ...[
                const SizedBox(height: 8),
                Text(result.message!,
                    style: const TextStyle(color: Colors.white)),
              ],
              if (isSuccess && canUndo) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: undoing ? null : onUndo,
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  icon: undoing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.undo),
                  label: const Text('Отменить чек-ин'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
