import 'package:flutter/material.dart';

import '../models/models.dart';

/// Loads a list with [load] and shows loading / error+retry / empty / items,
/// with pull-to-refresh. Call [AsyncListState.reload] via a GlobalKey to refresh.
class AsyncList<T> extends StatefulWidget {
  final Future<List<T>> Function() load;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String emptyText;

  const AsyncList({
    super.key,
    required this.load,
    required this.itemBuilder,
    required this.emptyText,
  });

  @override
  State<AsyncList<T>> createState() => AsyncListState<T>();
}

class AsyncListState<T> extends State<AsyncList<T>> {
  late Future<List<T>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  Future<void> reload() {
    setState(() => _future = widget.load());
    return _future.then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<T>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          final err = snap.error;
          return _Message(
            icon: Icons.wifi_off,
            text: err is ApiException ? err.message : 'Не удалось загрузить данные',
            action: OutlinedButton(onPressed: reload, child: const Text('Повторить')),
          );
        }
        final items = snap.data ?? [];
        return RefreshIndicator(
          onRefresh: reload,
          child: items.isEmpty
              ? ListView(children: [
                  const SizedBox(height: 120),
                  _Message(icon: Icons.inbox_outlined, text: widget.emptyText),
                ])
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (c, i) => widget.itemBuilder(c, items[i]),
                ),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;
  const _Message({required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}

/// Small coloured status label (colour + text, never colour alone).
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const StatusChip(this.label, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
