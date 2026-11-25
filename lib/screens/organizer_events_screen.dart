import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/async_list.dart';
import '../widgets/attendance_view.dart';
import 'event_detail_screen.dart';
import 'event_form_screen.dart';
import 'event_sales_screen.dart';
import 'manage_event_screen.dart';
import 'support_screens.dart';

Color eventStatusColor(String status) => switch (status) {
      'PUBLISHED' => Colors.green.shade700,
      'CANCELLED' => Colors.red.shade700,
      _ => Colors.orange.shade800,
    };

/// Organizer cabinet with event management, sales and support.
class OrganizerEventsScreen extends StatefulWidget {
  const OrganizerEventsScreen({super.key});

  @override
  State<OrganizerEventsScreen> createState() => _OrganizerEventsScreenState();
}

class _OrganizerEventsScreenState extends State<OrganizerEventsScreen> {
  int _tab = 0;
  late Future<List<EventInfo>> _future = _load();
  final _formKey = GlobalKey<EventFormState>();
  String? _phase; // History filter on "My events"; null = all.

  Future<List<EventInfo>> _load() => _phase == null
      ? api.getMyEvents(AuthService.user!.id)
      : api.getOrganizerEvents(phase: _phase);

  void _setPhase(String? phase) => setState(() {
        _phase = phase;
        _future = _load();
      });

  /// The history filter belongs to "My events": other tabs list every event.
  void _selectTab(int tab) => setState(() {
        _tab = tab;
        if (tab != 0 && _phase != null) {
          _phase = null;
          _future = _load();
        }
      });

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

  /// Publishing goes through the preview, where it is confirmed.
  Future<void> _preview(EventInfo e) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => EventDetailScreen(event: e, preview: true)),
    );
    _reload();
  }

  Future<void> _onCreated(EventInfo created) async {
    _toast(tr('org.created'));
    _formKey.currentState?.reset();
    _phase = null;
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
      tr('support.title'),
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
    } else if (_tab == 4) {
      body = const SupportListScreen(embedded: true);
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
                onCreate: () => _selectTab(1),
                onOpen: _open,
                onEdit: _edit,
                onRefresh: _reload,
                phase: _phase,
                onPhase: _setPhase,
              ),
            2 => _ManageTab(
                events: events,
                onOpen: _open,
                onEdit: _edit,
                onChanged: _reload,
                onError: _toast,
                onPreview: _preview,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Wrap(
                spacing: 8,
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    ChoiceChip(
                      label: Text(tabs[i]),
                      selected: _tab == i,
                      showCheckmark: false,
                      selectedColor: cs.primary,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _tab == i ? cs.onPrimary : cs.onSurface,
                      ),
                      onSelected: (_) => _selectTab(i),
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
  final String? phase;
  final ValueChanged<String?> onPhase;
  const _MineTab({
    required this.events,
    required this.onCreate,
    required this.onOpen,
    required this.onEdit,
    required this.onRefresh,
    required this.phase,
    required this.onPhase,
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
        child: Column(children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            children: [
              for (final p in [null, ...eventPhases])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(p == null ? tr('support.all') : tr('phase.$p')),
                    selected: phase == p,
                    onSelected: (_) => onPhase(p),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
        child: RefreshIndicator(
          onRefresh: onRefresh,
          child: events.isEmpty
              ? ListView(children: [
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                        tr(phase == null ? 'org.empty' : 'phase.empty'),
                        textAlign: TextAlign.center),
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
                              [
                                if (e.phase != null) tr('phase.${e.phase}'),
                                if (e.venue != null) e.venue!.name,
                                if (e.startTime != null) formatDateTime(e.startTime!),
                              ].join(' · '),
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
        ]),
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
  final Future<void> Function(EventInfo) onPreview;
  const _ManageTab({
    required this.events,
    required this.onOpen,
    required this.onEdit,
    required this.onChanged,
    required this.onError,
    required this.onPreview,
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
                                        : e.status == 'PUBLISHED'
                                            ? () => _run(
                                                e, () => api.unpublishEvent(e.id))
                                            : () => widget.onPreview(e),
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

/// Sales calculated by the server from paid orders (SRS 4.15): revenue,
/// discounts, fees and estimated payout, per event and in total.
class _SalesTabState extends State<_SalesTab> {
  late Future<SalesSummary> _future = api.getSalesSummary();

  Future<void> _refresh() async {
    await widget.onRefresh();
    if (mounted) setState(() => _future = api.getSalesSummary());
    await _future.then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return _Section(
      title: tr('sales.title'),
      subtitle: tr('sales.sub'),
      child: Expanded(
        child: FutureBuilder<SalesSummary>(
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
            final summary = snap.data!;
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  SalesFiguresGrid(f: summary.totals),
                  const SizedBox(height: 14),
                  if (summary.events.isEmpty)
                    Text(tr('sales.noSales'),
                        style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                  for (final s in summary.events)
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: _cardShape(context),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.eventTitle,
                                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                            if (s.startTime != null)
                              Text(formatDateTime(s.startTime!),
                                  style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 20,
                              runSpacing: 4,
                              children: [
                                Text('${tr('sales.soldShort')}: ${s.figures.ticketsSold}'),
                                Text('${tr('sales.revenue')}: ${formatPrice(s.figures.revenue)}'),
                                Text('${tr('sales.net')}: ${formatPrice(s.figures.netRevenue)}'),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // A new key after each refresh reloads the counts.
                            AttendanceLine(
                                key: ObjectKey(s), eventId: s.eventId),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EventSalesScreen(
                                          eventId: s.eventId, title: s.eventTitle),
                                    ),
                                  ),
                                  icon: const Icon(Icons.insights),
                                  label: Text(tr('sales.details')),
                                ),
                                for (final e in widget.events.where((e) => e.id == s.eventId))
                                  OutlinedButton(
                                    onPressed: () => widget.onOpen(e, section: 'staff'),
                                    child: Text(tr('sales.staffBtn')),
                                  ),
                              ],
                            ),
                          ],
                        ),
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
