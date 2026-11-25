// Platform admin search and monitoring (SRS 4.12): events, orders, payments,
// refunds, reported events, fee settings and report export.
import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/file_share.dart';
import '../widgets/async_list.dart';
import '../widgets/date_range_filter.dart';
import 'admin_tools_screen.dart' show askReason;
import 'order_screen.dart' show orderStatusLabel;

void _toast(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

/// Search field and filter chips above a server-side result list.
class _SearchList<T> extends StatefulWidget {
  /// Null hides the search field.
  final String? hint;

  /// Filter value (null = all) to chip label.
  final Map<String?, String> filters;
  final String? initialFilter;
  final Future<PageResult<T>> Function(String query, String? filter) search;
  final Widget Function(T item, Future<void> Function() reload) itemBuilder;
  final String? emptyText;
  const _SearchList({
    super.key,
    this.hint,
    required this.filters,
    this.initialFilter,
    required this.search,
    required this.itemBuilder,
    this.emptyText,
  });

  @override
  State<_SearchList<T>> createState() => _SearchListState<T>();
}

class _SearchListState<T> extends State<_SearchList<T>> {
  final _list = GlobalKey<AsyncListState<T>>();
  final _query = TextEditingController();
  late String? _filter = widget.initialFilter;
  Timer? _debounce;
  int _shown = 0;
  bool _truncated = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _reload() async => _list.currentState?.reload();

  Future<List<T>> _load() async {
    final query = _query.text;
    final filter = _filter;
    final page = await widget.search(query, filter);
    // Only the answer to the current search may set the "more results" note.
    if (mounted && query == _query.text && filter == _filter) {
      setState(() {
        _shown = page.items.length;
        _truncated = !page.last;
      });
    }
    return page.items;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.hint != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              controller: _query,
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), _reload);
              },
              decoration: InputDecoration(
                hintText: widget.hint,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (final f in widget.filters.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f.value),
                    selected: _filter == f.key,
                    onSelected: (_) {
                      setState(() => _filter = f.key);
                      _reload();
                    },
                  ),
                ),
            ],
          ),
        ),
        if (_truncated)
          Text(tr('adm.truncated', {'n': _shown}),
              style: Theme.of(context).textTheme.bodySmall),
        Expanded(
          child: AsyncList<T>(
            key: _list,
            load: _load,
            emptyText: widget.emptyText ?? tr('adm.nothing'),
            itemBuilder: (context, item) => widget.itemBuilder(item, _reload),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------- Events

class AdminEventsTab extends StatefulWidget {
  const AdminEventsTab({super.key});

  @override
  State<AdminEventsTab> createState() => _AdminEventsTabState();
}

class _AdminEventsTabState extends State<AdminEventsTab> {
  final Set<int> _busy = {};

  Future<void> _toggle(EventInfo e, Future<void> Function() reload) async {
    String? reason;
    if (!e.suspended) {
      reason = await askReason(context, tr('adm.suspendEvent'));
      if (reason == null) return;
    }
    setState(() => _busy.add(e.id));
    try {
      e.suspended
          ? await api.unsuspendEvent(e.id)
          : await api.suspendEvent(e.id, reason!);
      if (mounted) {
        _toast(context,
            tr(e.suspended ? 'adm.eventResumed' : 'adm.eventSuspended'));
      }
      await reload();
    } on ApiException catch (err) {
      if (mounted) _toast(context, err.message);
    } finally {
      if (mounted) setState(() => _busy.remove(e.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _SearchList<EventInfo>(
      hint: tr('adm.searchEvents'),
      filters: {null: tr('support.all'), 'true': tr('adm.suspendedOnly')},
      search: (q, f) => api.searchAdminEvents(
          query: q, suspended: f == null ? null : true),
      emptyText: tr('adm.noEvents'),
      itemBuilder: (e, reload) => Card(
        child: ListTile(
          title: Text(e.title),
          subtitle: Text([
            e.subtitle,
            tr('ev.${e.status}'),
            if (e.suspended && e.suspensionReason != null)
              tr('adm.suspendedBecause', {'reason': e.suspensionReason}),
          ].where((s) => s.isNotEmpty).join('\n')),
          trailing: e.suspended
              ? FilledButton.tonal(
                  onPressed:
                      _busy.contains(e.id) ? null : () => _toggle(e, reload),
                  child: Text(tr('adm.resume')),
                )
              : OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: cs.error),
                  onPressed:
                      _busy.contains(e.id) ? null : () => _toggle(e, reload),
                  child: Text(tr('adm.suspend')),
                ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------ Orders, payments, refunds

class AdminOrdersTab extends StatelessWidget {
  const AdminOrdersTab({super.key});

  @override
  Widget build(BuildContext context) {
    return _SearchList<AdminOrder>(
      hint: tr('adm.searchOrders'),
      filters: {
        null: tr('support.all'),
        for (final s in OrderStatus.values)
          s.name.toUpperCase(): orderStatusLabel(s).$1,
      },
      search: (q, f) => api.searchAdminOrders(query: q, status: f),
      itemBuilder: (o, _) {
        final (label, color) = orderStatusLabel(o.status);
        return Card(
          child: ListTile(
            title: Text('${tr('orders.number', {'id': o.id})} • ${o.eventTitle}'),
            subtitle: Text([
              o.buyerEmail,
              [
                tr('orders.ticketsN', {'n': o.ticketCount}),
                if (o.createdAt != null) formatDateTime(o.createdAt!),
              ].join(' • '),
            ].join('\n')),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatPrice(o.totalAmount),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                StatusChip(label, color),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Payments, or refunds when [refunds] is true.
class AdminTransactionsTab extends StatelessWidget {
  final bool refunds;
  const AdminTransactionsTab({super.key, this.refunds = false});

  @override
  Widget build(BuildContext context) {
    return _SearchList<AdminTransaction>(
      hint: tr(refunds ? 'adm.searchRefunds' : 'adm.searchPayments'),
      filters: {
        null: tr('support.all'),
        for (final s in [if (refunds) 'PENDING', 'SUCCEEDED', 'FAILED'])
          s: tr('adm.payStatus.$s'),
      },
      search: (q, f) => refunds
          ? api.searchAdminRefunds(query: q, status: f)
          : api.searchAdminPayments(query: q, status: f),
      itemBuilder: (p, _) => Card(
        child: ListTile(
          title: Text(p.eventTitle.isEmpty ? p.reference : p.eventTitle),
          subtitle: Text([
            p.buyerEmail,
            [
              if (p.orderId != null) tr('orders.number', {'id': p.orderId}),
              if (p.createdAt != null) formatDateTime(p.createdAt!),
            ].join(' • '),
            [p.reference, p.provider].where((s) => s.isNotEmpty).join(' • '),
            p.reason ?? '',
            p.failureReason ?? '',
          ].where((s) => s.isNotEmpty).join('\n')),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatPrice(p.amount),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              StatusChip(
                  tr('adm.payStatus.${p.status}'),
                  switch (p.status) {
                    'SUCCEEDED' => Colors.green.shade700,
                    'FAILED' => Colors.red.shade700,
                    _ => Colors.orange.shade800,
                  }),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- Reported events

class AdminReportsTab extends StatefulWidget {
  const AdminReportsTab({super.key});

  @override
  State<AdminReportsTab> createState() => _AdminReportsTabState();
}

class _AdminReportsTabState extends State<AdminReportsTab> {
  final Set<int> _busy = {};

  Future<void> _run(EventReport r, Future<void> Function() action,
      Future<void> Function() reload) async {
    setState(() => _busy.add(r.id));
    try {
      await action();
      await reload();
    } on ApiException catch (e) {
      if (mounted) _toast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(r.id));
    }
  }

  Future<void> _review(
      EventReport r, String outcome, Future<void> Function() reload) async {
    final note = await askReason(context,
        tr(outcome == 'DISMISSED' ? 'adm.dismiss' : 'adm.actioned'),
        required: false, label: tr('adm.note'));
    if (note == null) return;
    await _run(r, () => api.reviewEventReport(r.id, outcome, note), reload);
  }

  Future<void> _suspend(EventReport r, Future<void> Function() reload) async {
    final reason = await askReason(context, tr('adm.suspendEvent'));
    if (reason == null) return;
    await _run(r, () => api.suspendEvent(r.eventId, reason), reload);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return _SearchList<EventReport>(
      filters: {
        for (final s in ['OPEN', 'DISMISSED', 'ACTIONED'])
          s: tr('adm.reportStatus.$s'),
        null: tr('support.all'),
      },
      initialFilter: 'OPEN',
      search: (_, f) => api.getEventReports(status: f),
      emptyText: tr('adm.noReports'),
      itemBuilder: (r, reload) {
        final busy = _busy.contains(r.id);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.eventTitle,
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('${tr('report.reason.${r.reason}')} • '
                    '${tr('adm.reportStatus.${r.status}')}'),
                if (r.message.isNotEmpty) Text(r.message),
                Text(
                  [
                    r.reporterEmail,
                    if (r.createdAt != null) formatDateTime(r.createdAt!),
                  ].join(' • '),
                  style: t.bodySmall,
                ),
                if ((r.resolutionNote ?? '').isNotEmpty)
                  Text(r.resolutionNote!, style: t.bodySmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (!r.eventSuspended)
                      OutlinedButton(
                        onPressed: busy ? null : () => _suspend(r, reload),
                        child: Text(tr('adm.suspendEvent')),
                      ),
                    if (r.status == 'OPEN') ...[
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => _review(r, 'DISMISSED', reload),
                        child: Text(tr('adm.dismiss')),
                      ),
                      FilledButton(
                        onPressed:
                            busy ? null : () => _review(r, 'ACTIONED', reload),
                        child: Text(tr('adm.actioned')),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ----------------------------------------------------------------- Fee settings

class AdminSettingsTab extends StatefulWidget {
  const AdminSettingsTab({super.key});

  @override
  State<AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends State<AdminSettingsTab> {
  // Limits enforced by the server.
  static const _maxFee = 1000000;
  static const _maxPercent = 50;

  final _form = GlobalKey<FormState>();
  final _fee = TextEditingController();
  final _percent = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fee.dispose();
    _percent.dispose();
    super.dispose();
  }

  void _show(PlatformSettings s) {
    _fee.text = '${s.activationFeeKzt}';
    _percent.text = '${s.processingFeePercent}';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await api.getPlatformSettings();
      if (mounted) _show(s);
    } on ApiException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  static num? _parse(String? v) =>
      num.tryParse((v ?? '').trim().replaceAll(',', '.'));

  String? Function(String?) _upTo(int max) => (v) {
        final n = _parse(v);
        return n == null || n < 0 || n > max
            ? tr('adm.range', {'max': max})
            : null;
      };

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final s = await api.savePlatformSettings(
          _parse(_fee.text)!, _parse(_percent.text)!);
      if (!mounted) return;
      _show(s);
      _toast(context, tr('adm.saved'));
    } on ApiException catch (e) {
      if (mounted) _toast(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _load, child: Text(tr('retry'))),
        ]),
      );
    }
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final (controller, label, max) in [
            (_fee, 'adm.activationFee', _maxFee),
            (_percent, 'adm.processingFee', _maxPercent),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TextFormField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: tr(label),
                    errorMaxLines: 2,
                    border: const OutlineInputBorder()),
                validator: _upTo(max),
              ),
            ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed: _saving ? null : _save,
            child: Text(tr('save')),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Report export

class AdminExportTab extends StatefulWidget {
  const AdminExportTab({super.key});

  @override
  State<AdminExportTab> createState() => _AdminExportTabState();
}

class _AdminExportTabState extends State<AdminExportTab> {
  DateTime? _from;
  DateTime? _to;
  String? _busy;

  Future<void> _export(String kind) async {
    setState(() => _busy = kind);
    try {
      final bytes = await api.getReportCsv(kind, from: _from, to: _to);
      final name = 'biletflow-$kind-${isoDate(DateTime.now())}.csv';
      if (!mounted) return;
      await shareFile(context, bytes, name, 'text/csv');
    } on ApiException catch (e) {
      if (mounted) _toast(context, e.message);
    } catch (_) {
      if (mounted) _toast(context, tr('adm.exportFailed'));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(tr('adm.exportHint')),
        const SizedBox(height: 12),
        DateRangeFilter(
          from: _from,
          to: _to,
          onChanged: (from, to) => setState(() {
            _from = from;
            _to = to;
          }),
        ),
        const SizedBox(height: 16),
        for (final kind in ['events', 'payments', 'payouts'])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              onPressed: _busy == null ? () => _export(kind) : null,
              icon: _busy == kind
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.file_download_outlined),
              label: Text(tr('adm.report.$kind')),
            ),
          ),
      ],
    );
  }
}

// --------------------------------------------------------- Venue seating plans

/// Gives venues a seating plan, which assigned seating needs (SRS 4.3.1).
class AdminVenuesTab extends StatefulWidget {
  const AdminVenuesTab({super.key});

  @override
  State<AdminVenuesTab> createState() => _AdminVenuesTabState();
}

class _AdminVenuesTabState extends State<AdminVenuesTab> {
  final _list = GlobalKey<AsyncListState<Venue>>();
  List<SeatingLayout> _layouts = [];
  bool _busy = false;

  Future<List<Venue>> _load() async {
    final layouts = await api.getSeatingLayouts();
    final venues = await api.getVenues();
    _layouts = layouts;
    return venues;
  }

  Future<void> _assign(Venue v, String? layout) async {
    setState(() => _busy = true);
    try {
      await api.setVenueLayout(v.id, layout);
    } on ApiException catch (e) {
      if (mounted) _toast(context, e.message);
    }
    // Reloading also restores the old value after a refused change.
    await _list.currentState?.reload();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return AsyncList<Venue>(
      key: _list,
      load: _load,
      emptyText: tr('adm.nothing'),
      itemBuilder: (context, v) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(v.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              Text(v.address),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                key: ValueKey('${v.id}-${v.seatingLayout}'),
                initialValue: _layouts.any((l) => l.key == v.seatingLayout)
                    ? v.seatingLayout
                    : null,
                isExpanded: true,
                decoration: InputDecoration(
                    labelText: tr('seat.layout'),
                    isDense: true,
                    border: const OutlineInputBorder()),
                items: [
                  DropdownMenuItem(
                      value: null, child: Text(tr('seat.noLayout'))),
                  for (final l in _layouts)
                    DropdownMenuItem(
                        value: l.key,
                        child: Text('${l.name} · ${l.capacity}',
                            overflow: TextOverflow.ellipsis)),
                ],
                onChanged: _busy ? null : (key) => _assign(v, key),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
