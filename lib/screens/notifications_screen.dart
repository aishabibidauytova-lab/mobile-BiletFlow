import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/async_list.dart';
import 'order_screen.dart';

/// In-app notifications (SRS 4.10): order confirmations, payment failures,
/// event updates, refunds, support replies.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

IconData _icon(String type) {
  final t = type.toUpperCase();
  if (t.contains('SUPPORT')) return Icons.forum_outlined;
  if (t.contains('PAYMENT') || t.contains('REFUND')) return Icons.payments_outlined;
  if (t.contains('CANCEL')) return Icons.event_busy;
  if (t.contains('TICKET') || t.contains('ORDER')) return Icons.confirmation_number_outlined;
  if (t.contains('EVENT')) return Icons.event_note;
  return Icons.notifications_outlined;
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _list = GlobalKey<AsyncListState<AppNotification>>();
  bool _busy = false;

  Future<void> _readAll() async {
    setState(() => _busy = true);
    try {
      await api.markAllNotificationsRead();
      await _list.currentState?.reload();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(AppNotification n) async {
    if (!n.isRead) {
      try {
        await api.markNotificationRead(n.id);
      } on ApiException {
        // Not critical: the notification just stays unread.
      }
    }
    if (n.orderId != null && mounted) {
      try {
        final order = await api.getOrder(n.orderId!);
        if (!mounted) return;
        await Navigator.push(
            context, MaterialPageRoute(builder: (_) => OrderScreen(order: order)));
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    }
    _list.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('notif.title')),
        actions: [
          TextButton(
            onPressed: _busy ? null : _readAll,
            child: Text(tr('notif.readAll')),
          ),
        ],
      ),
      body: AsyncList<AppNotification>(
        key: _list,
        load: api.getNotifications,
        emptyText: tr('notif.empty'),
        itemBuilder: (context, n) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: n.isRead ? null : cs.primaryContainer.withValues(alpha: 0.35),
          child: ListTile(
            onTap: () => _open(n),
            leading: Icon(_icon(n.type), color: n.isRead ? cs.outline : cs.primary),
            title: Text(n.title,
                style: TextStyle(fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w800)),
            subtitle: Text([
              n.body,
              if (n.createdAt != null) formatDateTime(n.createdAt!),
            ].where((s) => s.isNotEmpty).join('\n')),
            isThreeLine: n.body.isNotEmpty,
            trailing: n.isRead
                ? null
                : Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                  ),
          ),
        ),
      ),
    );
  }
}

/// App-bar bell with the unread count. Refreshes when it is rebuilt or tapped.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final n = await api.getUnreadCount();
      if (mounted) setState(() => _unread = n);
    } catch (_) {
      // Offline: keep the last count.
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tr('notif.title'),
      onPressed: () async {
        await Navigator.push(
            context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
        _refresh();
      },
      icon: Badge(
        isLabelVisible: _unread > 0,
        label: Text(_unread > 99 ? '99+' : '$_unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
