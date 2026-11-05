import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../services/api_service.dart';

/// Display order of the known categories (unknown ones go last).
const knownCategories = ['Education', 'Music', 'Festival', 'Sport', 'Theatre'];

const _categoryIcons = {
  'Education': Icons.school_outlined,
  'Music': Icons.music_note_outlined,
  'Festival': Icons.festival_outlined,
  'Sport': Icons.sports_soccer_outlined,
  'Theatre': Icons.theater_comedy_outlined,
  'Концерт': Icons.mic_external_on_outlined,
};

/// Translated category name; unknown categories are shown as-is.
String categoryLabel(String c) {
  final t = tr('cat.$c');
  return t == 'cat.$c' ? c : t;
}

IconData categoryIcon(String c) =>
    _categoryIcons[c] ?? Icons.local_activity_outlined;

String monthShort(DateTime d) => tr('m${d.month}');

const _palettes = <List<Color>>[
  [Color(0xFF5B3FD0), Color(0xFF8E6BFF)], // violet
  [Color(0xFFD6336C), Color(0xFFFF8A5B)], // pink -> orange
  [Color(0xFF0B7A75), Color(0xFF38C6A8)], // teal
  [Color(0xFF1C4ED8), Color(0xFF4FB3FF)], // blue
  [Color(0xFFB4381C), Color(0xFFFFB347)], // ember
  [Color(0xFF2B2D42), Color(0xFF6C63A8)], // night
];

/// Gradient colours for an event: by category when known, else by id.
List<Color> posterPalette(int id, [String category = '']) {
  switch (category) {
    case 'Education':
      return _palettes[3];
    case 'Music':
      return _palettes[1];
    case 'Festival':
      return _palettes[4];
    case 'Концерт':
      return _palettes[0];
    case 'Sport':
      return _palettes[2];
    case 'Theatre':
      return _palettes[5];
  }
  return _palettes[id.abs() % _palettes.length];
}

List<Color> _paletteFor(EventInfo e) => posterPalette(e.id, e.category);

/// Event poster: the uploaded image when there is one, otherwise a generated
/// gradient poster (category colours, decorative shapes, icon and title).
class EventPoster extends StatelessWidget {
  final EventInfo event;

  /// Draw the title on generated posters (for large hero areas).
  final bool showTitle;

  const EventPoster({super.key, required this.event, this.showTitle = false});

  @override
  Widget build(BuildContext context) {
    final url = event.posterUrl;
    if (url == null || url.isEmpty) return _generated(context);
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      headers: api.authHeaders,
      errorBuilder: (_, _, _) => _generated(context),
      loadingBuilder: (c, child, p) => p == null ? child : _generated(c),
    );
  }

  Widget _generated(BuildContext context) {
    final colors = _paletteFor(event);
    final seed = event.id.abs();
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth.isFinite ? box.maxWidth : 300.0;
      final h = box.maxHeight.isFinite ? box.maxHeight : 180.0;
      final s = w < h ? w : h;
      // Deterministic per-event variation of the decorative shapes.
      final flip = seed.isEven;
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: flip ? Alignment.topLeft : Alignment.topRight,
            end: flip ? Alignment.bottomRight : Alignment.bottomLeft,
            colors: colors,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              right: flip ? -s * 0.25 : null,
              left: flip ? null : -s * 0.25,
              top: -s * 0.3,
              child: _circle(s * 0.95, 0.10),
            ),
            Positioned(
              left: flip ? -s * 0.2 : null,
              right: flip ? null : -s * 0.2,
              bottom: -s * 0.4,
              child: _circle(s * 0.8, 0.08),
            ),
            Positioned(
              right: flip ? w * 0.18 : null,
              left: flip ? null : w * 0.18,
              bottom: h * 0.18,
              child: _circle(s * 0.16, 0.14),
            ),
            Positioned(
              right: flip ? 16 : null,
              left: flip ? null : 16,
              bottom: 12,
              child: Icon(categoryIcon(event.category),
                  size: s * 0.42, color: Colors.white.withValues(alpha: 0.22)),
            ),
            if (showTitle)
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: Text(
                  event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _circle(double d, double alpha) => Container(
        width: d,
        height: d,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: alpha),
        ),
      );
}

/// Small "5 / НОЯ" date badge shown on posters.
class DateBadge extends StatelessWidget {
  final DateTime date;
  const DateBadge(this.date, {super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 46,
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${date.day}',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, height: 1.1)),
          Text(monthShort(date),
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: cs.primary)),
        ],
      ),
    );
  }
}
