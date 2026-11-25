import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/async_list.dart';
import 'activation_screen.dart' show activationStatusLabel;
import 'support_screens.dart';

/// Platform admin moderation (SRS 4.12): organizer verification, paid-sales
/// activations, event suspension and escalated support cases.
class AdminToolsScreen extends StatelessWidget {
  const AdminToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('adm.title')),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: tr('adm.verification')),
              Tab(text: tr('adm.activations')),
              Tab(text: tr('adm.events')),
              Tab(text: tr('adm.escalated')),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _VerificationTab(), _ActivationsTab(), _EventsTab(),
            SupportListScreen(escalatedOnly: true, embedded: true),
          ],
        ),
      ),
    );
  }
}

/// Asks the admin for a reason (suspension, rejection note). Null = cancelled.
Future<String?> askReason(BuildContext context, String title, {bool required = true}) async {
  final ctrl = TextEditingController();
  final r = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLines: 3,
        decoration: InputDecoration(
            labelText: tr('adm.reason'), border: const OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('no'))),
        FilledButton(
          onPressed: () {
            if (required && ctrl.text.trim().isEmpty) return;
            Navigator.pop(c, ctrl.text.trim());
          },
          child: Text(tr('adm.confirm')),
        ),
      ],
    ),
  );
  ctrl.dispose();
  return r;
}

void _toast(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

class _VerificationTab extends StatefulWidget {
  const _VerificationTab();

  @override
  State<_VerificationTab> createState() => _VerificationTabState();
}

class _VerificationTabState extends State<_VerificationTab> {
  final _list = GlobalKey<AsyncListState<VerificationRequest>>();
  final Set<int> _busy = {};

  Future<void> _review(VerificationRequest r, bool approved) async {
    String? note;
    if (!approved) {
      note = await askReason(context, tr('adm.reject'));
      if (note == null) return;
    }
    setState(() => _busy.add(r.profileId));
    try {
      await api.reviewOrganizer(r.profileId, approved, note: note);
      if (mounted) _toast(context, approved ? tr('adm.approved') : tr('adm.rejected'));
      await _list.currentState?.reload();
    } on ApiException catch (e) {
      if (mounted) _toast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(r.profileId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncList<VerificationRequest>(
      key: _list,
      load: api.getVerificationRequests,
      emptyText: tr('adm.noRequests'),
      itemBuilder: (context, r) {
        final busy = _busy.contains(r.profileId);
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: Text(r.email),
                  subtitle: Text('${r.contactInformation}\n${tr('verif.${r.status}')}'),
                  isThreeLine: true,
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: busy ? null : () => _review(r, false),
                      child: Text(tr('adm.reject')),
                    ),
                    FilledButton(
                      onPressed: busy ? null : () => _review(r, true),
                      child: Text(tr('adm.approve')),
                    ),
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

class _ActivationsTab extends StatefulWidget {
  const _ActivationsTab();

  @override
  State<_ActivationsTab> createState() => _ActivationsTabState();
}

class _ActivationsTabState extends State<_ActivationsTab> {
  final _list = GlobalKey<AsyncListState<Activation>>();
  String? _status;
  final Set<int> _busy = {};

  Future<void> _toggle(Activation a) async {
    final suspend = a.status != 'SUSPENDED';
    String? reason;
    if (suspend) {
      reason = await askReason(context, tr('adm.suspendSales'));
      if (reason == null) return;
    }
    setState(() => _busy.add(a.eventId));
    try {
      suspend
          ? await api.suspendPaidSales(a.eventId, reason!)
          : await api.unsuspendPaidSales(a.eventId);
      await _list.currentState?.reload();
    } on ApiException catch (e) {
      if (mounted) _toast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(a.eventId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (final s in [null, 'IN_PROGRESS', 'ACTIVE', 'SUSPENDED'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(s == null ? tr('support.all') : activationStatusLabel(s).$1),
                    selected: _status == s,
                    onSelected: (_) {
                      setState(() => _status = s);
                      _list.currentState?.reload();
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: AsyncList<Activation>(
            key: _list,
            load: () => api.getActivations(status: _status),
            emptyText: tr('adm.noActivations'),
            itemBuilder: (context, a) {
              final (label, color) = activationStatusLabel(a.status);
              final done = a.checklist.where((c) => c.done).length;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(a.eventTitle),
                  subtitle: Text([
                    tr('adm.checklist', {'done': done, 'all': a.checklist.length}),
                    if (a.feePaidAt != null)
                      tr('adm.feePaid', {'amount': formatPrice(a.feeAmount)}),
                    if (a.suspensionReason != null) a.suspensionReason!,
                  ].join(' • ')),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusChip(label, color),
                      if (a.status != 'IN_PROGRESS')
                        TextButton(
                          style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero),
                          onPressed: _busy.contains(a.eventId) ? null : () => _toggle(a),
                          child: Text(a.status == 'SUSPENDED'
                              ? tr('adm.resume')
                              : tr('adm.suspend')),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EventsTab extends StatefulWidget {
  const _EventsTab();

  @override
  State<_EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<_EventsTab> {
  final _list = GlobalKey<AsyncListState<EventInfo>>();
  final Set<int> _busy = {};

  Future<void> _toggle(EventInfo e) async {
    String? reason;
    if (!e.suspended) {
      reason = await askReason(context, tr('adm.suspendEvent'));
      if (reason == null) return;
    }
    setState(() => _busy.add(e.id));
    try {
      e.suspended ? await api.unsuspendEvent(e.id) : await api.suspendEvent(e.id, reason!);
      if (mounted) {
        _toast(context, e.suspended ? tr('adm.eventResumed') : tr('adm.eventSuspended'));
      }
      await _list.currentState?.reload();
    } on ApiException catch (err) {
      if (mounted) _toast(context, err.message);
    } finally {
      if (mounted) setState(() => _busy.remove(e.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AsyncList<EventInfo>(
      key: _list,
      load: api.getEvents,
      emptyText: tr('adm.noEvents'),
      itemBuilder: (context, e) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          title: Text(e.title),
          subtitle: Text([
            e.subtitle,
            if (e.suspended && e.suspensionReason != null)
              tr('adm.suspendedBecause', {'reason': e.suspensionReason}),
          ].where((s) => s.isNotEmpty).join('\n')),
          trailing: e.suspended
              ? FilledButton.tonal(
                  onPressed: _busy.contains(e.id) ? null : () => _toggle(e),
                  child: Text(tr('adm.resume')),
                )
              : OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: cs.error),
                  onPressed: _busy.contains(e.id) ? null : () => _toggle(e),
                  child: Text(tr('adm.suspend')),
                ),
        ),
      ),
    );
  }
}
