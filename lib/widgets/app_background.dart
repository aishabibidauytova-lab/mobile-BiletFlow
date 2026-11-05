import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Colour of the backdrop base (used where a "cut-out" must blend in).
const kBackdropColor = Color(0xFFF6F6F9);

/// Fixed decorative backdrop behind every screen: a clean light base covered
/// with a scattered pattern of event-themed line icons (tickets, music,
/// theatre, QR…), plus a faint brand tint at the top. Screens use transparent
/// scaffolds so it shows through.
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const RepaintBoundary(
          child: DecoratedBox(
            decoration: BoxDecoration(color: kBackdropColor),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: _PatternPainter()),
                // Soft brand tint fading out from the top edge.
                Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    height: 260,
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x265B3FD0), Color(0x005B3FD0)],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

const _icons = <IconData>[
  Icons.confirmation_number_outlined,
  Icons.music_note_outlined,
  Icons.theater_comedy_outlined,
  Icons.festival_outlined,
  Icons.school_outlined,
  Icons.mic_external_on_outlined,
  Icons.qr_code_2,
  Icons.star_outline_rounded,
  Icons.local_activity_outlined,
  Icons.sports_soccer_outlined,
  Icons.celebration_outlined,
  Icons.headphones_outlined,
  Icons.palette_outlined,
  Icons.camera_alt_outlined,
  Icons.emoji_events_outlined,
  Icons.piano_outlined,
];

const _sizes = [26.0, 32.0, 40.0];

class _PatternPainter extends CustomPainter {
  const _PatternPainter();

  // One laid-out glyph per (icon, size); built once and reused.
  static final Map<int, TextPainter> _glyphs = {};

  static TextPainter _glyph(int icon, int sizeIdx) {
    return _glyphs.putIfAbsent(icon * 10 + sizeIdx, () {
      final i = _icons[icon];
      return TextPainter(
        text: TextSpan(
          text: String.fromCharCode(i.codePoint),
          style: TextStyle(
            fontFamily: i.fontFamily,
            package: i.fontPackage,
            fontSize: _sizes[sizeIdx],
            color: const Color(0xFF2A2350).withValues(alpha: 0.075),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 104.0;
    final rnd = math.Random(7); // fixed seed: the same pattern every time
    var row = 0;
    for (var y = 0.0; y < size.height + cell; y += cell, row++) {
      // Offset every other row (brick layout) so it doesn't look like a grid.
      final shift = row.isEven ? 0.0 : cell / 2;
      for (var x = -cell + shift; x < size.width + cell; x += cell) {
        final icon = rnd.nextInt(_icons.length);
        final sizeIdx = rnd.nextInt(_sizes.length);
        final angle = (rnd.nextDouble() - 0.5) * 1.0; // about ±29°
        final dx = x + (rnd.nextDouble() - 0.5) * 26;
        final dy = y + (rnd.nextDouble() - 0.5) * 26;
        final tp = _glyph(icon, sizeIdx);
        canvas.save();
        canvas.translate(dx, dy);
        canvas.rotate(angle);
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_PatternPainter old) => false;
}
