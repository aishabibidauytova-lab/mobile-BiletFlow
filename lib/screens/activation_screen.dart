import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/async_list.dart';

/// Paid sales activation for one event (SRS 3.2, 4.5): a checklist with an
/// action for every step. Fee payment is a clearly labelled simulation.
class ActivationScreen extends StatefulWidget {
  final EventInfo event;
  const ActivationScreen({super.key, required this.event});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

(String, Color) activationStatusLabel(String s) => switch (s) {
      'ACTIVE' => (tr('act.status.ACTIVE'), Colors.green.shade700),
      'SUSPENDED' => (tr('act.status.SUSPENDED'), Colors.red.shade700),
      _ => (tr('act.status.IN_PROGRESS'), Colors.orange.shade800),
    };

class _ActivationScreenState extends State<ActivationScreen> {
  Activation? _act;
  PayoutAccount? _payout;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        api.getActivation(widget.event.id),
        api.getPayoutAccount().catchError((_) => null),
      ]);
      if (!mounted) return;
      setState(() {
        _act = results[0] as Activation;
        _payout = results[1] as PayoutAccount?;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _run(Future<void> Function() action, [String? done]) async {
    setState(() => _busy = true);
    try {
      await action();
      if (done != null) _toast(done);
      await _load();
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editPayout() async {
    final bank = TextEditingController(text: _payout?.bankName ?? '');
    final holder = TextEditingController(text: _payout?.accountHolder ?? '');
    final iban = TextEditingController();
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('act.payoutTitle')),
        content: Form(
          key: form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tr('act.payoutHint'), style: Theme.of(c).textTheme.bodySmall),
                const SizedBox(height: 12),
                TextFormField(
                  controller: bank,
                  decoration: InputDecoration(
                      labelText: tr('act.bank'), border: const OutlineInputBorder()),
                  validator: (v) => (v ?? '').trim().isEmpty ? tr('support.required') : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: holder,
                  decoration: InputDecoration(
                      labelText: tr('act.holder'), border: const OutlineInputBorder()),
                  validator: (v) => (v ?? '').trim().isEmpty ? tr('support.required') : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: iban,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                      labelText: 'IBAN', hintText: 'KZ…', border: const OutlineInputBorder()),
                  validator: (v) {
                    final s = (v ?? '').replaceAll(' ', '');
                    return s.length < 15 ? tr('act.ibanInvalid') : null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('no'))),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(c, true);
            },
            child: Text(tr('admin.saveChanges')),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _run(
          () => api.savePayoutAccount(bank.text.trim(), holder.text.trim(),
              iban.text.replaceAll(' ', '').toUpperCase()),
          tr('act.payoutSaved'));
    }
    bank.dispose();
    holder.dispose();
    iban.dispose();
  }

  Future<void> _acceptTerms() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('act.termsTitle')),
        content: SingleChildScrollView(child: Text(tr('act.termsBody'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('no'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('act.accept'))),
        ],
      ),
    );
    if (ok == true) {
      await _run(() => api.activationStep(widget.event.id, 'accept-terms'));
    }
  }

  /// The action button for one checklist step, or null when nothing to do here.
  Widget? _stepAction(ChecklistItem item) {
    if (item.done && item.key != 'PAYOUT_ACCOUNT') return null;
    return switch (item.key) {
      'IDENTITY_VERIFIED' => FilledButton.tonal(
          onPressed: _busy
              ? null
              : () => _run(() => api.requestVerification(), tr('act.verificationRequested')),
          child: Text(tr('act.requestVerification')),
        ),
      'PAYOUT_ACCOUNT' => FilledButton.tonal(
          onPressed: _busy ? null : _editPayout,
          child: Text(item.done ? tr('edit') : tr('act.addPayout')),
        ),
      'FEE_PAID' => FilledButton.tonal(
          onPressed: _busy
              ? null
              : () => _run(() => api.activationStep(widget.event.id, 'pay-fee'),
                  tr('act.feePaid')),
          child: Text(tr('act.payFee', {'amount': formatPrice(_act?.feeAmount ?? 0)})),
        ),
      'TERMS_ACCEPTED' => FilledButton.tonal(
          onPressed: _busy ? null : _acceptTerms,
          child: Text(tr('act.acceptTerms')),
        ),
      _ => null, // PAID_TICKET_TYPE: done on the event's ticket types screen.
    };
  }

  @override
  Widget build(BuildContext context) {
    final a = _act;
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('act.title'))),
      body: a == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: _load, child: Text(tr('retry'))),
                    ]),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(widget.event.title,
                      style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      StatusChip(activationStatusLabel(a.status).$1,
                          activationStatusLabel(a.status).$2),
                      if (a.simulated) ...[
                        const SizedBox(width: 8),
                        StatusChip(tr('order.simulated'), Colors.amber.shade900),
                      ],
                    ],
                  ),
                  if (a.status == 'SUSPENDED' && a.suspensionReason != null) ...[
                    const SizedBox(height: 8),
                    Text(tr('act.suspendedReason', {'reason': a.suspensionReason}),
                        style: TextStyle(color: cs.error)),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      border: Border.all(color: Colors.amber.shade700),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(tr('act.demoNote'),
                        style: TextStyle(color: Colors.amber.shade900)),
                  ),
                  const SizedBox(height: 16),
                  for (final item in a.checklist)
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            ListTile(
                              leading: Icon(
                                item.done ? Icons.check_circle : Icons.radio_button_unchecked,
                                color: item.done ? Colors.green.shade700 : cs.outline,
                              ),
                              title: Text(_stepTitle(item)),
                              subtitle: _stepSubtitle(item, a),
                            ),
                            ?_stepAction(item),
                            if (_stepAction(item) != null) const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (a.status != 'ACTIVE')
                    FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      onPressed: _busy || !a.readyToActivate || a.status == 'SUSPENDED'
                          ? null
                          : () => _run(() => api.activationStep(widget.event.id, 'activate'),
                              tr('act.activated')),
                      icon: const Icon(Icons.rocket_launch_outlined),
                      label: Text(tr('act.activate')),
                    )
                  else
                    ListTile(
                      leading: Icon(Icons.verified, color: Colors.green.shade700),
                      title: Text(tr('act.isActive')),
                      subtitle: a.activatedAt == null
                          ? null
                          : Text(formatDateTime(a.activatedAt!)),
                    ),
                  if (!a.readyToActivate && a.status == 'IN_PROGRESS')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(tr('act.notReady'),
                          textAlign: TextAlign.center, style: t.bodySmall),
                    ),
                ],
              ),
            ),
    );
  }

  String _stepTitle(ChecklistItem item) {
    final s = tr('act.step.${item.key}');
    return s == 'act.step.${item.key}' ? item.label : s;
  }

  Widget? _stepSubtitle(ChecklistItem item, Activation a) {
    final text = switch (item.key) {
      'PAID_TICKET_TYPE' when !item.done => tr('act.needPaidType'),
      'PAYOUT_ACCOUNT' when _payout != null =>
        '${_payout!.bankName} • ${_payout!.accountHolder} • ••••${_payout!.ibanLast4}',
      'FEE_PAID' when a.feePaidAt != null => [
          formatDateTime(a.feePaidAt!),
          if (a.feeReference != null) a.feeReference!,
        ].join(' • '),
      'TERMS_ACCEPTED' when a.termsAcceptedAt != null => formatDateTime(a.termsAcceptedAt!),
      _ => null,
    };
    return text == null ? null : Text(text);
  }
}
