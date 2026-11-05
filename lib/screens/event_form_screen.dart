import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/date_time_field.dart';
import '../widgets/event_poster.dart';

/// Full-screen create ([event] == null) or edit page. Pops with the saved event.
class EventFormScreen extends StatelessWidget {
  final EventInfo? event;
  const EventFormScreen({super.key, this.event});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(event != null ? tr('form.editTitle') : tr('form.newTitle')),
      ),
      body: EventForm(
        event: event,
        onSaved: (saved) => Navigator.pop(context, saved),
      ),
    );
  }
}

/// The event form itself, usable as a page body or embedded in a tab.
/// Create ([event] == null) or edit; [onSaved] receives the saved event.
class EventForm extends StatefulWidget {
  final EventInfo? event;
  final ValueChanged<EventInfo> onSaved;
  final bool showReset;
  const EventForm({
    super.key,
    this.event,
    required this.onSaved,
    this.showReset = false,
  });

  @override
  State<EventForm> createState() => EventFormState();
}

class EventFormState extends State<EventForm> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.event?.title);
  late final _description = TextEditingController(text: widget.event?.description);
  late final _category = TextEditingController(text: widget.event?.category);
  late final _capacity =
      TextEditingController(text: widget.event?.capacity?.toString() ?? '');

  DateTime? _start;
  DateTime? _end;
  DateTime? _regOpen;
  DateTime? _regClose;
  String _visibility = 'PUBLIC';
  int? _venueId;
  List<Venue> _venues = [];
  bool _loadingVenues = true;
  bool _saving = false;
  bool _startMissing = false;

  // Poster chosen in the form; uploaded right after the event is saved
  // (the server needs the event id first).
  Uint8List? _posterBytes;
  String _posterName = 'poster.jpg';
  String _posterMime = 'image/jpeg';

  bool get _editing => widget.event != null;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    if (e != null) {
      _start = e.startTime;
      _end = e.endTime;
      _regOpen = e.registrationOpeningTime;
      _regClose = e.registrationClosingTime;
      _visibility = e.visibility;
      _venueId = e.venue?.id;
    }
    _loadVenues();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _category.dispose();
    _capacity.dispose();
    super.dispose();
  }

  Future<void> _loadVenues() async {
    try {
      final v = await api.getVenues();
      if (mounted) setState(() => _venues = v);
    } catch (_) {
      // The dropdown just stays empty; the user can still add a venue.
    } finally {
      if (mounted) setState(() => _loadingVenues = false);
    }
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _addVenue() async {
    final name = TextEditingController();
    final address = TextEditingController();
    final cap = TextEditingController();
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('form.newVenue')),
        content: Form(
          key: form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  autofocus: true,
                  decoration: InputDecoration(
                      labelText: tr('form.venueName'), border: const OutlineInputBorder()),
                  validator: _req,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: address,
                  decoration: InputDecoration(
                      labelText: tr('form.venueAddress'), border: const OutlineInputBorder()),
                  validator: _req,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: cap,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: tr('form.venueCapacity'), border: const OutlineInputBorder()),
                  validator: _positiveInt,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('cancel'))),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(c, true);
            },
            child: Text(tr('create')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final v = await api.createVenue(
          name.text.trim(), address.text.trim(), int.parse(cap.text.trim()));
      setState(() {
        _venues = [..._venues, v];
        _venueId = v.id;
      });
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  String? _req(String? v) => (v ?? '').trim().isEmpty ? tr('required') : null;

  String? _positiveInt(String? v) {
    final n = int.tryParse((v ?? '').trim());
    return n == null || n <= 0 ? tr('enterNumber') : null;
  }

  Future<void> _pickPoster() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    if (bytes.length > 5 * 1024 * 1024) {
      _toast(tr('poster.tooBig'));
      return;
    }
    final name = file.name.toLowerCase();
    setState(() {
      _posterBytes = bytes;
      _posterName = file.name;
      _posterMime = name.endsWith('.png')
          ? 'image/png'
          : name.endsWith('.webp')
              ? 'image/webp'
              : 'image/jpeg';
    });
  }

  /// Clears every field (used after creating an event and by the Clear button).
  void reset() {
    _form.currentState?.reset();
    setState(() {
      _title.clear();
      _description.clear();
      _category.clear();
      _capacity.clear();
      _start = null;
      _end = null;
      _regOpen = null;
      _regClose = null;
      _visibility = 'PUBLIC';
      _venueId = null;
      _startMissing = false;
      _posterBytes = null;
    });
  }

  Future<void> _save() async {
    final valid = _form.currentState!.validate();
    setState(() => _startMissing = _start == null);
    if (!valid || _start == null) return;
    if (_venueId == null) {
      _toast(tr('form.pickVenue'));
      return;
    }
    final e = widget.event;
    final capacity = int.tryParse(_capacity.text.trim());

    final body = <String, dynamic>{
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'category': _category.text.trim(),
      // On edit, only send the start time if it changed (the server requires
      // it to be in the future, which an already-running event isn't).
      if (e == null || _start != e.startTime) 'startTime': isoLocal(_start!),
      if (_end != null) 'endTime': isoLocal(_end!),
      if (_regOpen != null) 'registrationOpeningTime': isoLocal(_regOpen!),
      if (_regClose != null) 'registrationClosingTime': isoLocal(_regClose!),
      'capacity': ?capacity,
      'visibilityStatus': _visibility,
      'venueId': _venueId,
    };

    setState(() => _saving = true);
    try {
      final saved = e == null
          ? await api.createEvent(body)
          : await api.updateEvent(e.id, body);
      var result = saved;
      final bytes = _posterBytes;
      if (bytes != null) {
        try {
          result = await api.uploadPoster(saved.id, bytes, _posterName, _posterMime);
        } on ApiException catch (err) {
          // The event itself is saved; only the poster failed.
          _toast(tr('form.posterFailed', {'msg': err.message}));
        }
      }
      if (mounted) widget.onSaved(result);
    } on ApiException catch (err) {
      _toast(err.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _posterPicker(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasExisting = (widget.event?.posterUrl ?? '').isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('manage.poster'),
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        if (_posterBytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.memory(_posterBytes!, fit: BoxFit.cover),
            ),
          ),
        if (_posterBytes != null) const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickPoster,
              icon: const Icon(Icons.image_outlined),
              label: Text(_posterBytes != null || hasExisting
                  ? tr('manage.replace')
                  : tr('manage.upload')),
            ),
            if (_posterBytes != null)
              TextButton.icon(
                onPressed: _saving ? null : () => setState(() => _posterBytes = null),
                icon: const Icon(Icons.close),
                label: Text(tr('form.clear')),
              ),
            Text(tr('manage.posterHint'),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const gap = SizedBox(height: 14);
    InputDecoration deco(String label) =>
        InputDecoration(labelText: label, border: const OutlineInputBorder());

    return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                TextFormField(
                    controller: _title, decoration: deco(tr('form.title')), validator: _req),
                gap,
                TextFormField(
                  controller: _description,
                  decoration: deco(tr('form.description')),
                  minLines: 3,
                  maxLines: 6,
                ),
                gap,
                TextFormField(
                    controller: _category, decoration: deco(tr('form.category')), validator: _req),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final c in knownCategories)
                      ActionChip(
                        avatar: Icon(categoryIcon(c), size: 16),
                        label: Text(categoryLabel(c)),
                        onPressed: () => setState(() => _category.text = c),
                      ),
                  ],
                ),
                gap,
                DateTimeField(
                  label: tr('form.start'),
                  value: _start,
                  clearable: false,
                  errorText: _startMissing && _start == null ? tr('required') : null,
                  onChanged: (v) => setState(() => _start = v),
                ),
                gap,
                DateTimeField(
                    label: tr('form.end'), value: _end, onChanged: (v) => setState(() => _end = v)),
                gap,
                DateTimeField(
                    label: tr('form.regOpen'),
                    value: _regOpen,
                    onChanged: (v) => setState(() => _regOpen = v)),
                gap,
                DateTimeField(
                    label: tr('form.regClose'),
                    value: _regClose,
                    onChanged: (v) => setState(() => _regClose = v)),
                gap,
                TextFormField(
                  controller: _capacity,
                  keyboardType: TextInputType.number,
                  decoration: deco(tr('form.capacity')),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? null : _positiveInt(v),
                ),
                gap,
                Text(tr('form.visibility'),
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [
                    for (final v in const ['PUBLIC', 'UNLISTED', 'PRIVATE'])
                      ButtonSegment(value: v, label: Text(tr('vis.$v'))),
                  ],
                  selected: {_visibility},
                  onSelectionChanged: (s) => setState(() => _visibility = s.first),
                ),
                gap,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _loadingVenues
                          ? const LinearProgressIndicator()
                          : DropdownButtonFormField<int>(
                              initialValue: _venues.any((v) => v.id == _venueId)
                                  ? _venueId
                                  : null,
                              isExpanded: true,
                              decoration: deco(tr('form.venue')),
                              items: [
                                for (final v in _venues)
                                  DropdownMenuItem(
                                    value: v.id,
                                    child: Text(
                                      v.capacity == null
                                          ? v.name
                                          : '${v.name} (${v.capacity})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (v) => setState(() => _venueId = v),
                            ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: tr('form.newVenue'),
                      onPressed: _addVenue,
                      icon: const Icon(Icons.add_location_alt_outlined),
                    ),
                  ],
                ),
                gap,
                _posterPicker(context),
                const SizedBox(height: 28),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_editing ? tr('save') : tr('create')),
                ),
                if (widget.showReset) ...[
                  const SizedBox(height: 10),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: _saving ? null : reset,
                    child: Text(tr('form.clear')),
                  ),
                ],
              ],
            ),
          ),
        ),
    );
  }
}
