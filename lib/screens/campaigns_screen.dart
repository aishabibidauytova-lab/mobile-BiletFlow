import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/async_list.dart';
import '../widgets/date_time_field.dart';

/// Promo campaigns of one event (SRS 4.14): unique code, Campaign QR code and
/// redemption / revenue statistics per campaign.
class CampaignsScreen extends StatefulWidget {
  final EventInfo event;
  const CampaignsScreen({super.key, required this.event});

  @override
  State<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends State<CampaignsScreen> {
  final _list = GlobalKey<AsyncListState<Campaign>>();
  final Set<int> _busy = {};

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _create() async {
    final created = await Navigator.push<Campaign>(context,
        MaterialPageRoute(builder: (_) => _CampaignFormScreen(event: widget.event)));
    if (created != null) {
      _toast(tr('camp.created', {'code': created.code}));
      _list.currentState?.reload();
    }
  }

  Future<void> _toggle(Campaign c) async {
    setState(() => _busy.add(c.id));
    try {
      await api.setCampaignEnabled(widget.event.id, c.id, !c.enabled);
      await _list.currentState?.reload();
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(c.id));
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _toast(tr('ticket.copied'));
  }

  void _showQr(Campaign c) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(c.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                child: Image.network(
                  api.campaignQrUri(widget.event.id, c.id).toString(),
                  headers: api.authHeaders,
                  width: 240,
                  height: 240,
                  errorBuilder: (_, _, _) => SizedBox(
                      width: 240, height: 240, child: Center(child: Text(tr('ticket.qrFailed')))),
                ),
              ),
              const SizedBox(height: 10),
              Text(tr('camp.qrHint'), textAlign: TextAlign.center,
                  style: Theme.of(ctx).textTheme.bodySmall),
            ],
          ),
          actions: [
            if (c.campaignUrl.isNotEmpty)
              TextButton(onPressed: () => _copy(c.campaignUrl), child: Text(tr('camp.copyLink'))),
            FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('admin.close'))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('camp.title'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: Text(tr('camp.new')),
      ),
      body: AsyncList<Campaign>(
        key: _list,
        load: () => api.getCampaigns(widget.event.id),
        emptyText: tr('camp.empty'),
        itemBuilder: (context, c) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(c.name,
                          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    StatusChip(c.enabled ? tr('camp.active') : tr('camp.disabled'),
                        c.enabled ? Colors.green.shade700 : Colors.blueGrey),
                    Switch(
                      value: c.enabled,
                      onChanged: _busy.contains(c.id) ? null : (_) => _toggle(c),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(c.code,
                        style: t.titleSmall?.copyWith(
                            fontFamily: 'monospace', color: cs.primary, fontWeight: FontWeight.w700)),
                    IconButton(
                      tooltip: tr('ticket.copy'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _copy(c.code),
                      icon: const Icon(Icons.copy, size: 18),
                    ),
                    const SizedBox(width: 4),
                    Text(c.discountLabel,
                        style: t.titleSmall?.copyWith(
                            color: Colors.green.shade700, fontWeight: FontWeight.w800)),
                  ],
                ),
                Text(
                  [
                    if (c.validUntil != null)
                      tr('camp.until', {'date': formatDateTime(c.validUntil!)}),
                    if (c.maxRedemptions != null)
                      tr('camp.remaining',
                          {'n': c.remainingRedemptions, 'max': c.maxRedemptions}),
                  ].join(' • '),
                  style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    _Metric(tr('camp.redemptions'), '${c.redemptions}'),
                    _Metric(tr('sales.sold'), '${c.ticketsSold}'),
                    _Metric(tr('camp.discountGiven'), formatPrice(c.discountAmount)),
                    _Metric(tr('sales.net'), formatPrice(c.netRevenue)),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _showQr(c),
                    icon: const Icon(Icons.qr_code_2),
                    label: Text(tr('camp.showQr')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.labelSmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
        Text(value, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _CampaignFormScreen extends StatefulWidget {
  final EventInfo event;
  const _CampaignFormScreen({required this.event});

  @override
  State<_CampaignFormScreen> createState() => _CampaignFormScreenState();
}

class _CampaignFormScreenState extends State<_CampaignFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _value = TextEditingController();
  final _max = TextEditingController();
  String _type = 'PERCENT';
  DateTime? _from;
  DateTime? _until;
  late final Future<List<TicketType>> _types = api.getAllTicketTypes(widget.event.id);
  final Set<int> _selected = {};
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _value.dispose();
    _max.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_from != null && _until != null && !_until!.isAfter(_from!)) {
      setState(() => _error = tr('camp.datesInvalid'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final c = await api.createCampaign(widget.event.id, {
        'name': _name.text.trim(),
        'discountType': _type,
        'discountValue': num.parse(_value.text.trim().replaceAll(',', '.')),
        if (_from != null) 'validFrom': isoLocal(_from!),
        if (_until != null) 'validUntil': isoLocal(_until!),
        if (_max.text.trim().isNotEmpty) 'maxRedemptions': int.parse(_max.text.trim()),
        if (_selected.isNotEmpty) 'ticketTypeIds': _selected.toList(),
      });
      if (mounted) Navigator.pop(context, c);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validateValue(String? v) {
    final n = num.tryParse((v ?? '').trim().replaceAll(',', '.'));
    if (n == null || n <= 0) return tr('camp.valueInvalid');
    if (_type == 'PERCENT' && n > 100) return tr('camp.valueInvalid');
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('camp.new'))),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: InputDecoration(
                  labelText: tr('camp.name'), border: const OutlineInputBorder()),
              validator: (v) => (v ?? '').trim().isEmpty ? tr('support.required') : null,
            ),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'PERCENT', label: Text(tr('camp.percent'))),
                ButtonSegment(value: 'FIXED', label: Text(tr('camp.fixed'))),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _value,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: tr('camp.value'),
                suffixText: _type == 'PERCENT' ? '%' : '₸',
                border: const OutlineInputBorder(),
              ),
              validator: _validateValue,
            ),
            const SizedBox(height: 14),
            DateTimeField(
                label: tr('camp.validFrom'), value: _from, onChanged: (d) => setState(() => _from = d)),
            const SizedBox(height: 14),
            DateTimeField(
                label: tr('camp.validUntil'), value: _until, onChanged: (d) => setState(() => _until = d)),
            const SizedBox(height: 14),
            TextFormField(
              controller: _max,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: tr('camp.maxRedemptions'),
                helperText: tr('camp.maxHint'),
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return null;
                final n = int.tryParse(s);
                return n == null || n <= 0 ? tr('camp.valueInvalid') : null;
              },
            ),
            const SizedBox(height: 18),
            Text(tr('camp.ticketTypes'), style: Theme.of(context).textTheme.titleSmall),
            Text(tr('camp.ticketTypesHint'), style: Theme.of(context).textTheme.bodySmall),
            FutureBuilder<List<TicketType>>(
              future: _types,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Padding(
                      padding: EdgeInsets.all(12), child: LinearProgressIndicator());
                }
                return Column(
                  children: [
                    for (final tt in snap.data!)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _selected.contains(tt.id),
                        title: Text(tt.name),
                        subtitle: Text(formatPrice(tt.price)),
                        onChanged: (v) => setState(
                            () => v == true ? _selected.add(tt.id) : _selected.remove(tt.id)),
                      ),
                  ],
                );
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: cs.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              onPressed: _saving ? null : _save,
              child: Text(tr('camp.create')),
            ),
          ],
        ),
      ),
    );
  }
}
