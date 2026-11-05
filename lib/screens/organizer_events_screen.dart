import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/async_list.dart';
import 'event_form_screen.dart';
import 'manage_event_screen.dart';

Color eventStatusColor(String status) => switch (status) {
      'PUBLISHED' => Colors.green.shade700,
      'CANCELLED' => Colors.red.shade700,
      _ => Colors.orange.shade800,
    };

/// Organizer cabinet (mirrors the website): My events, Create, Management and
/// Sales sections.
class OrganizerEventsScreen extends StatefulWidget {
  const OrganizerEventsScreen({super.key});

  @override
  State<OrganizerEventsScreen> createState() => _OrganizerEventsScreenState();
}

class _OrganizerEventsScreenState extends State<OrganizerEventsScreen> {
  int _tab = 0;
  late Future<List<EventInfo>> _future = _load();
  final _formKey = GlobalKey<EventFormState>();

  Future<List<EventInfo>> _load() => api.getMyEvents(AuthService.user!.id);

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future.then((_) {}, onError: (_) {});
  }

  void _toast(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _open(EventInfo e, {String? section}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ManageEventScreen(event: e, section: section)),
    );
    _reload();
  }

  Future<void> _edit(EventInfo e) async {
    final saved = await Navigator.push<EventInfo>(
      context,
      MaterialPageRoute(builder: (_) => EventFormScreen(event: e)),
    );
    if (saved != null) _reload();
  }

  Future<void> _onCreated(EventInfo created) async {
    _toast(tr('org.created'));
    _formKey.currentState?.reset();
    await _reload();
    if (mounted) setState(() => _tab = 0);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final tabs = [
      tr('org.tab.mine'),
      tr('org.tab.create'),
      tr('org.tab.manage'),
      tr('org.tab.sales'),
    ];

    Widget body;
    if (_tab == 1) {
      body = _Section(
        title: tr('org.tab.create'),
        subtitle: tr('org.createSub'),
        child: Expanded(
          child: EventForm(key: _formKey, onSaved: _onCreated, showReset: true),
        ),
      );
    } else {
      body = FutureBuilder<List<EventInfo>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            final err = snap.error;
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(err is ApiException ? err.message : tr('err.load')),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _reload, child: Text(tr('retry'))),
              ]),
            );
          }
          final events = snap.data ?? [];
          return switch (_tab) {
            0 => _MineTab(
                events: events,
                onCreate: () => setState(() => _tab = 1),
                onOpen: _open,
                onEdit: _edit,
                onRefresh: _reload,
              ),
            2 => _ManageTab(
                events: events,
                onOpen: _open,
                onEdit: _edit,
                onChanged: _reload,
                onError: _toast,
              ),
            _ => _SalesTab(events: events, onOpen: _open, onRefresh: _reload),
          };
        },
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('org.cabinet'),
                      style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  Text(tr('org.heading'),
                      style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(tabs[i]),
                        selected: _tab == i,
                        showCheckmark: false,
                        selectedColor: cs.primary,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _tab == i ? cs.onPrimary : cs.onSurface,
                        ),
                        onSelected: (_) => setState(() => _tab = i),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// Section heading (title, subtitle, optional trailing button) above [child].
class _Section extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Widget child;
  const _Section({
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
        ),
        child,
      ],
    );
  }
}

ShapeBorder _cardShape(BuildContext context) => RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    );

// ---------------------------------------------------------------- My events

class _MineTab extends StatelessWidget {
  final List<EventInfo> events;
  final VoidCallback onCreate;
  final Future<void> Function(EventInfo, {String? section}) onOpen;
  final Future<void> Function(EventInfo) onEdit;
  final Future<void> Function() onRefresh;
  const _MineTab({
    required this.events,
    required this.onCreate,
    required this.onOpen,
    required this.onEdit,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return _Section(
      title: tr('org.tab.mine'),
      subtitle: tr('org.mineSub'),
      trailing: FilledButton.icon(
        onPressed: onCreate,
        icon: const Icon(Icons.add),
        label: Text(tr('org.new')),
      ),
      child: Expanded(
        child: RefreshIndicator(
          onRefresh: onRefresh,
          child: events.isEmpty
              ? ListView(children: [
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(tr('org.empty'), textAlign: TextAlign.center),
                  ),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: events.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final e = events[i];
                    return Card(
                      margin: EdgeInsets.zero,
                      shape: _cardShape(context),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(e.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: t.titleMedium
                                          ?.copyWith(fontWeight: FontWeight.w800)),
                                ),
                                StatusChip(tr('ev.${e.status}'), eventStatusColor(e.status)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [if (e.venue != null) e.venue!.name, if (e.startTime != null) formatDateTime(e.startTime!)]
                                  .join(' · '),
                              style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                            ),
                            Wrap(
                              children: [
                                TextButton(
                                    onPressed: () => onOpen(e, section: 'tickets'),
                                    child: Text(tr('org.tickets'))),
                                TextButton(
                                    onPressed: () => onOpen(e, section: 'staff'),
                                    child: Text(tr('org.staff'))),
                                TextButton(
                                    onPressed: e.isCancelled ? null : () => onEdit(e),
                                    child: Text(tr('org.change'))),
                                TextButton(
                                    onPressed: () => onOpen(e),
                                    child: Text(tr('org.manage'))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- Management

class _ManageTab extends StatefulWidget {
  final List<EventInfo> events;
  final Future<void> Function(EventInfo, {String? section}) onOpen;
  final Future<void> Function(EventInfo) onEdit;
  final Future<void> Function() onChanged;
  final void Function(String) onError;
  const _ManageTab({
    required this.events,
    required this.onOpen,
    required this.onEdit,
    required this.onChanged,
    required this.onError,
  });

  @override
  State<_ManageTab> createState() => _ManageTabState();
}

class _ManageTabState extends State<_ManageTab> {
  final Set<int> _busy = {};

  Future<void> _run(EventInfo e, Future<void> Function() action) async {
    setState(() => _busy.add(e.id));
    try {
      await action();
      await widget.onChanged();
    } on ApiException catch (err) {
      widget.onError(err.message);
    } finally {
      if (mounted) setState(() => _busy.remove(e.id));
    }
  }

  Future<void> _cancel(EventInfo e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('manage.cancelTitle')),
        content: Text(tr('manage.cancelBody')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('no'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error),
            onPressed: () => Navigator.pop(c, true),
            child: Text(tr('manage.cancelEvent')),
          ),
        ],
      ),
    );
    if (ok == true) _run(e, () => api.cancelEvent(e.id));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return _Section(
      title: tr('org.tab.manage'),
      subtitle: tr('org.manageSub'),
      child: Expanded(
        child: RefreshIndicator(
          onRefresh: widget.onChanged,
          child: widget.events.isEmpty
              ? ListView(children: [
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(tr('org.empty'), textAlign: TextAlign.center),
                  ),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: widget.events.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final e = widget.events[i];
                    final busy = _busy.contains(e.id);
                    return Card(
                      margin: EdgeInsets.zero,
                      shape: _cardShape(context),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(e.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: t.titleMedium
                                              ?.copyWith(fontWeight: FontWeight.w800)),
                                      Text(
                                        [if (e.startTime != null) formatDateTime(e.startTime!), 'ID: ${e.id}']
                                            .join(' · '),
                                        style: t.bodySmall
                                            ?.copyWith(color: cs.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                                StatusChip(tr('ev.${e.status}'), eventStatusColor(e.status)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (busy) const LinearProgressIndicator(),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.tonal(
                                  onPressed: () => widget.onOpen(e, section: 'tickets'),
                                  child: Text(tr('org.tickets')),
                                ),
                                FilledButton.tonal(
                                  onPressed: busy || e.isCancelled ? null : () => widget.onEdit(e),
                                  child: Text(tr('org.change')),
                                ),
                                if (!e.isCancelled)
                                  FilledButton.tonal(
                                    onPressed: busy
                                        ? null
                                        : () => _run(
                                              e,
                                              () => e.status == 'PUBLISHED'
                                                  ? api.unpublishEvent(e.id)
                                                  : api.publishEvent(e.id),
                                            ),
                                    child: Text(e.status == 'PUBLISHED'
                                        ? tr('org.unpublishShort')
                                        : tr('org.publishShort')),
                                  ),
                                if (!e.isCancelled)
                                  FilledButton.tonal(
                                    style: FilledButton.styleFrom(foregroundColor: cs.error),
                                    onPressed: busy ? null : () => _cancel(e),
                                    child: Text(tr('org.cancelShort')),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------- Sales

class _SalesTab extends StatefulWidget {
  final List<EventInfo> events;
  final Future<void> Function(EventInfo, {String? section}) onOpen;
  final Future<void> Function() onRefresh;
  const _SalesTab({required this.events, required this.onOpen, required this.onRefresh});

  @override
  State<_SalesTab> createState() => _SalesTabState();
}

class _SalesTabState extends State<_SalesTab> {
  late Future<List<List<TicketType>>> _future = _load();

  Future<List<List<TicketType>>> _load() =>
      Future.wait([for (final e in widget.events) api.getAllTicketTypes(e.id)]);

  Future<void> _refresh() async {
    await widget.onRefresh();
    if (mounted) setState(() => _future = _load());
    await _future.then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _Section(
      title: tr('sales.title'),
      subtitle: tr('sales.sub'),
      child: Expanded(
        child: FutureBuilder<List<List<TicketType>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              final err = snap.error;
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(err is ApiException ? err.message : tr('err.load')),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _refresh, child: Text(tr('retry'))),
                ]),
              );
            }
            final byEvent = snap.data ?? [];
            var sold = 0, left = 0;
            num sum = 0;
            for (final types in byEvent) {
              for (final t in types) {
                sold += t.sold;
                left += t.available;
                sum += t.price * t.sold;
              }
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  Row(
                    children: [
                      Expanded(child: _Stat(tr('sales.sold'), '$sold')),
                      const SizedBox(width: 10),
                      Expanded(child: _Stat(tr('sales.left'), '$left')),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _Stat(tr('sales.estimate'),
                              sum == 0 ? '0 ₸' : formatPrice(sum))),
                    ],
                  ),
                  const SizedBox(height: 14),
                  for (var i = 0; i < widget.events.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _EventSales(
                        event: widget.events[i],
                        types: i < byEvent.length ? byEvent[i] : const [],
                        onStaff: () => widget.onOpen(widget.events[i], section: 'staff'),
                        color: cs.surface,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _EventSales extends StatelessWidget {
  final EventInfo event;
  final List<TicketType> types;
  final VoidCallback onStaff;
  final Color color;
  const _EventSales({
    required this.event,
    required this.types,
    required this.onStaff,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final sold = types.fold<int>(0, (s, x) => s + x.sold);
    final left = types.fold<int>(0, (s, x) => s + x.available);
    final sum = types.fold<num>(0, (s, x) => s + x.price * x.sold);
    String money(num v) => v == 0 ? '0 ₸' : formatPrice(v);

    TableRow row(List<String> cells, {bool header = false}) => TableRow(
          children: [
            for (var i = 0; i < cells.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Text(
                  cells[i],
                  textAlign: i == 0 ? TextAlign.left : TextAlign.right,
                  style: (header ? t.labelSmall : t.bodySmall)?.copyWith(
                    color: header ? cs.onSurfaceVariant : null,
                    fontWeight: header ? FontWeight.w700 : null,
                  ),
                ),
              ),
          ],
        );

    return Card(
      margin: EdgeInsets.zero,
      shape: _cardShape(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.title,
                          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      if (event.startTime != null)
                        Text(formatDateTime(event.startTime!),
                            style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                FilledButton.tonal(onPressed: onStaff, child: Text(tr('sales.staffBtn'))),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 4,
              children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: '${tr('sales.soldShort')}: '),
                  TextSpan(text: '$sold', style: const TextStyle(fontWeight: FontWeight.w800)),
                ])),
                Text.rich(TextSpan(children: [
                  TextSpan(text: '${tr('sales.leftShort')}: '),
                  TextSpan(text: '$left', style: const TextStyle(fontWeight: FontWeight.w800)),
                ])),
                Text.rich(TextSpan(children: [
                  TextSpan(text: '${tr('sales.sumShort')}: '),
                  TextSpan(text: money(sum), style: const TextStyle(fontWeight: FontWeight.w800)),
                ])),
              ],
            ),
            const SizedBox(height: 10),
            if (types.isEmpty)
              Text(tr('sales.noTypes'),
                  style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant))
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 520),
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2.2),
                      1: FlexColumnWidth(1.4),
                      2: FlexColumnWidth(1),
                      3: FlexColumnWidth(1),
                      4: FlexColumnWidth(1.6),
                    },
                    children: [
                      row([
                        tr('sales.colType'),
                        tr('sales.colPrice'),
                        tr('sales.colSold'),
                        tr('sales.colLeft'),
                        tr('sales.colSum'),
                      ], header: true),
                      for (final x in types)
                        row([
                          x.hidden ? '${x.name} (${tr('tt.hidden')})' : x.name,
                          money(x.price),
                          '${x.sold}',
                          '${x.available}',
                          money(x.price * x.sold),
                        ]),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
