import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/event_poster.dart';
import 'event_detail_screen.dart';

/// Public event catalog: search, category tabs, date strip, a featured banner
/// and event cards (mirrors the BiletFlow website).
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  late Future<List<EventInfo>> _future = _load();
  final _search = TextEditingController();
  String _query = '';
  String? _category; // null = all
  DateTime? _date; // null = any day

  // Cheapest-ticket label per event, loaded lazily and cached.
  final _prices = <int, Future<String?>>{};

  bool get _filtering => _category != null || _date != null || _query.isNotEmpty;

  Future<List<EventInfo>> _load() async {
    final events = await api.getEvents();
    return events.where((e) => e.status == 'PUBLISHED').toList();
  }

  Future<void> _reload() async {
    setState(() {
      _prices.clear();
      _future = _load();
    });
    await _future.then((_) {}, onError: (_) {});
  }

  Future<String?> _priceOf(EventInfo e) => _prices.putIfAbsent(e.id, () async {
        try {
          final types = await api.getTicketTypes(e.id);
          final onSale = types.where((t) => t.onSale).toList();
          if (onSale.isEmpty) return types.isEmpty ? null : tr('events.noTickets');
          final min = onSale.map((t) => t.price).reduce((a, b) => a < b ? a : b);
          if (min == 0) return tr('free');
          return onSale.length > 1
              ? tr('events.from', {'price': formatPrice(min)})
              : formatPrice(min);
        } catch (_) {
          return null;
        }
      });

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<EventInfo> _filter(List<EventInfo> all) {
    final q = _query.trim().toLowerCase();
    return all.where((e) {
      if (_category != null && e.category != _category) return false;
      if (_date != null &&
          (e.startTime == null || !_sameDay(e.startTime!, _date!))) {
        return false;
      }
      if (q.isNotEmpty &&
          !('${e.title} ${e.venue?.name ?? ''} ${categoryLabel(e.category)}')
              .toLowerCase()
              .contains(q)) {
        return false;
      }
      return true;
    }).toList();
  }

  void _resetFilters() => setState(() {
        _category = null;
        _date = null;
        _search.clear();
        _query = '';
      });

  void _open(EventInfo e) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EventDetailScreen(event: e)),
      );

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
    );
    if (d != null) setState(() => _date = d);
  }

  /// Nearest upcoming event, shown as the featured banner.
  EventInfo? _featured(List<EventInfo> all) {
    final now = DateTime.now();
    final upcoming = all
        .where((e) => e.startTime != null && e.startTime!.isAfter(now))
        .toList()
      ..sort((a, b) => a.startTime!.compareTo(b.startTime!));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EventInfo>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          final err = snap.error;
          return _Notice(
            icon: Icons.wifi_off,
            text: err is ApiException ? err.message : tr('err.load'),
            action: OutlinedButton(onPressed: _reload, child: Text(tr('retry'))),
          );
        }
        final all = snap.data ?? [];
        final known = knownCategories;
        final categories = <String>{
          for (final e in all)
            if (e.category.isNotEmpty) e.category,
        }.toList()
          ..sort((a, b) {
            final ia = known.indexOf(a);
            final ib = known.indexOf(b);
            return (ia < 0 ? 99 : ia).compareTo(ib < 0 ? 99 : ib);
          });
        final events = _filter(all);
        final featured = _filtering ? null : _featured(all);

        return RefreshIndicator(
          onRefresh: _reload,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _searchField()),
              SliverToBoxAdapter(child: _categoryTabs(categories)),
              SliverToBoxAdapter(child: _dateStrip()),
              if (featured != null)
                SliverToBoxAdapter(
                  child: _FeaturedBanner(event: featured, onTap: () => _open(featured)),
                ),
              SliverToBoxAdapter(child: _heading(events.length)),
              if (events.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _Notice(
                    icon: Icons.search_off,
                    text: tr('events.none'),
                    action: OutlinedButton(
                      onPressed: _resetFilters,
                      child: Text(tr('events.reset')),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: SliverGrid.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 340,
                      mainAxisExtent: 310,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: events.length,
                    itemBuilder: (_, i) => _EventCard(
                      event: events[i],
                      price: _priceOf(events[i]),
                      onTap: () => _open(events[i]),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _searchField() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: SearchBar(
          controller: _search,
          hintText: tr('events.search'),
          leading: const Icon(Icons.search),
          elevation: const WidgetStatePropertyAll(0),
          onChanged: (v) => setState(() => _query = v),
          trailing: [
            if (_query.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _search.clear();
                  _query = '';
                }),
              ),
          ],
        ),
      );

  Widget _categoryTabs(List<String> categories) {
    final cs = Theme.of(context).colorScheme;
    Widget tab(String label, String? value, IconData icon) {
      final selected = _category == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          avatar: Icon(icon,
              size: 18, color: selected ? cs.onPrimary : cs.onSurfaceVariant),
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          selectedColor: cs.primary,
          labelStyle: TextStyle(
            color: selected ? cs.onPrimary : cs.onSurface,
            fontWeight: FontWeight.w600,
          ),
          onSelected: (_) => setState(() {
            _category = value;
            // "Все" shows everything: also clear the date filter.
            if (value == null) _date = null;
          }),
        ),
      );
    }

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
        children: [
          tab(tr('events.all'), null, Icons.apps),
          for (final c in categories) tab(categoryLabel(c), c, categoryIcon(c)),
        ],
      ),
    );
  }

  Widget _dateStrip() {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = [for (var i = 0; i < 14; i++) today.add(Duration(days: i))];
    final pickedOutside = _date != null && !days.any((d) => _sameDay(d, _date!));

    Widget chip(DateTime d, int i) {
      final selected = _date != null && _sameDay(d, _date!);
      final weekend = d.weekday >= 6;
      final fg = selected
          ? cs.onPrimary
          : weekend
              ? Colors.deepOrange
              : cs.onSurface;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _date = selected ? null : d),
          child: Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selected ? cs.primary : cs.surface,
              border: Border.all(color: selected ? cs.primary : cs.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(i == 0 ? tr('events.today') : tr('wd${d.weekday}'),
                    style: TextStyle(fontSize: i == 0 ? 9.5 : 11, color: fg)),
                const SizedBox(height: 2),
                Text('${d.day}',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700, color: fg)),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 84,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        children: [
          for (var i = 0; i < days.length; i++) chip(days[i], i),
          if (pickedOutside)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InputChip(
                label: Text(formatDateTime(_date!).substring(0, 10)),
                onDeleted: () => setState(() => _date = null),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month, size: 18),
              label: Text(tr('events.pickDate')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heading(int count) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            _category == null ? tr('events.allEvents') : categoryLabel(_category!),
            style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 10),
          Text('$count', style: t.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Large banner for the nearest upcoming event.
class _FeaturedBanner extends StatelessWidget {
  final EventInfo event;
  final VoidCallback onTap;
  const _FeaturedBanner({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final date = event.startTime;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 210,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                EventPoster(event: event),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xB3000000)],
                      stops: [0.35, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  top: 18,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt, size: 14, color: Color(0xFFE8590C)),
                        const SizedBox(width: 4),
                        Text(tr('events.nearest'),
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8)),
                      ],
                    ),
                  ),
                ),
                if (date != null) Positioned(right: 18, top: 16, child: DateBadge(date)),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.1),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        event.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                    ],
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

class _EventCard extends StatelessWidget {
  final EventInfo event;
  final Future<String?> price;
  final VoidCallback onTap;
  const _EventCard({required this.event, required this.price, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final date = event.startTime;

    return Material(
      color: cs.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  EventPoster(event: event),
                  if (event.category.isNotEmpty)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.surface.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          categoryLabel(event.category).toUpperCase(),
                          style: t.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800, letterSpacing: 0.6),
                        ),
                      ),
                    ),
                  if (date != null) Positioned(right: 10, top: 10, child: DateBadge(date)),
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: FutureBuilder<String?>(
                      future: price,
                      builder: (_, s) {
                        final label = s.data;
                        if (label == null || label.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        final free = label == tr('free');
                        return Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: free ? const Color(0xFF16A34A) : Colors.black87,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(label,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  if (date != null)
                    _MetaRow(Icons.schedule, formatDateTime(date)),
                  if (event.venue != null) ...[
                    const SizedBox(height: 3),
                    _MetaRow(Icons.place_outlined, event.venue!.name),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 15, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant)),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;
  const _Notice({required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) => Center(
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
