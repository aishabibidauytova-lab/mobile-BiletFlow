// Drawing of a hall (sections) and of one section's seats. Every state has a
// symbol or text besides its colour.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';

void _text(Canvas canvas, String text, Offset center, double size, Color color,
    {double? maxWidth, FontWeight weight = FontWeight.w600}) {
  final painter = TextPainter(
    text: TextSpan(
        text: text,
        style: TextStyle(fontSize: size, color: color, fontWeight: weight)),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
    maxLines: 2,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth ?? double.infinity);
  painter.paint(
      canvas, center - Offset(painter.width / 2, painter.height / 2));
  painter.dispose();
}

/// The whole hall, scaled to the available width. Tapping a section reports it.
class HallPlan extends StatelessWidget {
  final SeatMap map;
  final int? activeSectionId;

  /// Which sections react to taps.
  final bool Function(SeatSection) enabled;

  /// Seats already picked, per section id.
  final Map<int, int> picked;
  final ValueChanged<SeatSection> onTap;
  const HallPlan({
    super.key,
    required this.map,
    required this.enabled,
    required this.onTap,
    this.activeSectionId,
    this.picked = const {},
  });

  static Rect _rect(SeatArea a, double scale) => Rect.fromLTWH(
      a.x * scale, a.y * scale, a.width * scale, a.height * scale);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      // Fit the width, within the height the screen leaves for the plan.
      final scale = math.min(box.maxWidth / map.width,
          math.min(box.maxHeight, 340) / map.height);
      return Center(
        child: SizedBox(
          width: map.width * scale,
          height: map.height * scale,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _HallPainter(map, scale, activeSectionId, enabled,
                      picked, Theme.of(context).colorScheme),
                ),
              ),
              for (final s in map.sections)
                Positioned.fromRect(
                  rect: _rect(s.area, scale),
                  child: Semantics(
                    button: enabled(s),
                    selected: s.id == activeSectionId,
                    label: '${s.name}, '
                        '${tr('seat.free', {'n': s.available})}'
                        '${s.price == null ? '' : ', ${formatPrice(s.price!)}'}',
                    child: Tooltip(
                      message: s.name,
                      excludeFromSemantics: true,
                      child: GestureDetector(
                        key: ValueKey('section-${s.id}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: enabled(s) ? () => onTap(s) : null,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _HallPainter extends CustomPainter {
  final SeatMap map;
  final double scale;
  final int? active;
  final bool Function(SeatSection) enabled;
  final Map<int, int> picked;
  final ColorScheme cs;
  _HallPainter(this.map, this.scale, this.active, this.enabled, this.picked,
      this.cs);

  @override
  void paint(Canvas canvas, Size size) {
    final stage = map.stage;
    if (stage != null) {
      final r = HallPlan._rect(stage, scale);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)),
          Paint()..color = Colors.grey.shade800);
      _text(canvas, stage.label, r.center, 11, Colors.white,
          maxWidth: r.width);
    }
    for (final s in map.sections) {
      final r = HallPlan._rect(s.area, scale).deflate(1);
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(6));
      final isActive = s.id == active;
      final on = enabled(s);
      canvas.drawRRect(
          rr,
          Paint()
            ..color = isActive
                ? cs.primary
                : on
                    ? Colors.white
                    : Colors.grey.shade300);
      canvas.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = on || isActive ? cs.primary : Colors.grey.shade500);
      final count = picked[s.id] ?? 0;
      _text(
          canvas,
          [
            count > 0 ? '${s.key} · $count' : s.key,
            s.price == null ? '—' : formatPrice(s.price!),
          ].join('\n'),
          r.center,
          // Narrow sections get smaller text, so prices are not cut off.
          math.min(11, math.min(r.height / 3, r.width / 4.8)),
          isActive ? cs.onPrimary : Colors.black87,
          maxWidth: r.width);
    }
  }

  @override
  bool shouldRepaint(_HallPainter old) => true;
}

/// How one seat is drawn.
class _SeatStyle {
  final Color color;
  final String symbol;
  final String labelKey;
  const _SeatStyle(this.color, this.symbol, this.labelKey);

  static _SeatStyle of(SeatStatus s) => switch (s) {
        SeatStatus.available =>
          _SeatStyle(Colors.green.shade200, '', 'seat.available'),
        SeatStatus.held =>
          _SeatStyle(Colors.amber.shade300, '…', 'seat.held'),
        SeatStatus.yours =>
          _SeatStyle(Colors.blue.shade200, 'Y', 'seat.yours'),
        SeatStatus.sold => _SeatStyle(Colors.grey.shade500, '×', 'seat.sold'),
        SeatStatus.unavailable =>
          _SeatStyle(Colors.grey.shade300, '—', 'seat.unavailable'),
      };
}

class SeatLegend extends StatelessWidget {
  const SeatLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget item(Color color, String symbol, String key, {Color? border}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border:
                    border == null ? null : Border.all(color: border, width: 3),
              ),
              child: Text(symbol,
                  style: TextStyle(
                      fontSize: 10,
                      color: color == cs.primary ? cs.onPrimary : Colors.black)),
            ),
            const SizedBox(width: 4),
            Text(tr(key), style: Theme.of(context).textTheme.bodySmall),
          ],
        );
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (final s in SeatStatus.values)
          item(_SeatStyle.of(s).color, _SeatStyle.of(s).symbol,
              _SeatStyle.of(s).labelKey),
        item(cs.primary, '✓', 'seat.selected'),
        item(Colors.white, '', 'seat.accessible',
            border: Colors.lightBlue.shade700),
      ],
    );
  }
}

/// Pixel positions of a section's seats, with the closest two seats
/// [SeatGrid.spacing] pixels apart.
class _Geometry {
  late final List<Offset> centers;
  late final Map<String, Offset> rowLabels;
  late final Size size;

  _Geometry(List<Seat> seats) {
    final rows = <String, List<Seat>>{};
    for (final s in seats) {
      rows.putIfAbsent(s.row, () => []).add(s);
    }
    var step = double.infinity;
    for (final row in rows.values) {
      row.sort((a, b) => a.number.compareTo(b.number));
      for (var i = 1; i < row.length; i++) {
        final d = Offset(row[i].x - row[i - 1].x, row[i].y - row[i - 1].y)
            .distance;
        if (d > 0 && d < step) step = d;
      }
    }
    if (!step.isFinite) step = 10;
    final scale = SeatGrid.spacing / step;

    // A row's label sits just before its first seat, along the row.
    final labels = <String, Offset>{};
    for (final e in rows.entries) {
      final first = Offset(e.value.first.x, e.value.first.y);
      final along = Offset(e.value.last.x, e.value.last.y) - first;
      final unit = along.distance > 0
          ? along / along.distance
          : const Offset(1, 0);
      labels[e.key] = (first - unit * step * 1.2) * scale;
    }
    final points = [
      for (final s in seats) Offset(s.x, s.y) * scale,
      ...labels.values,
    ];
    var min = points.first, max = points.first;
    for (final p in points) {
      min = Offset(math.min(min.dx, p.dx), math.min(min.dy, p.dy));
      max = Offset(math.max(max.dx, p.dx), math.max(max.dy, p.dy));
    }
    const pad = Offset(SeatGrid.spacing, SeatGrid.spacing);
    final shift = pad - min;
    centers = [for (final s in seats) Offset(s.x, s.y) * scale + shift];
    rowLabels = {for (final e in labels.entries) e.key: e.value + shift};
    size = Size(max.dx - min.dx + 2 * pad.dx, max.dy - min.dy + 2 * pad.dy);
  }
}

/// The seats of one section. Drag to move; pinch, scroll or use the buttons to
/// zoom.
class SeatGrid extends StatefulWidget {
  static const double spacing = 32;

  final List<Seat> seats;
  final Set<int> selected;
  final bool Function(Seat) enabled;
  final ValueChanged<Seat> onTap;
  const SeatGrid({
    super.key,
    required this.seats,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<SeatGrid> createState() => _SeatGridState();
}

class _SeatGridState extends State<SeatGrid> {
  static const _minScale = 0.2;
  static const _maxScale = 2.0;

  late _Geometry _geometry = _Geometry(widget.seats);
  final _view = TransformationController();
  Size _viewport = Size.zero;

  @override
  void dispose() {
    _view.dispose();
    super.dispose();
  }

  /// Zooms around the middle of what is on screen.
  void _zoom(double factor) {
    final scale = _view.value.getMaxScaleOnAxis();
    final next = (scale * factor).clamp(_minScale, _maxScale);
    final center = _viewport.center(Offset.zero);
    final scene = _view.toScene(center);
    _view.value = Matrix4.identity()
      ..translateByDouble(center.dx - scene.dx * next,
          center.dy - scene.dy * next, 0, 1)
      ..scaleByDouble(next, next, next, 1);
  }

  @override
  void didUpdateWidget(SeatGrid old) {
    super.didUpdateWidget(old);
    if (!identical(old.seats, widget.seats)) {
      _geometry = _Geometry(widget.seats);
    }
  }

  void _tap(Offset at) {
    for (var i = 0; i < widget.seats.length; i++) {
      if ((_geometry.centers[i] - at).distance <= SeatGrid.spacing / 2) {
        final seat = widget.seats[i];
        if (widget.enabled(seat)) widget.onTap(seat);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.seats.isEmpty) {
      return Center(child: Text(tr('seat.none')));
    }
    return LayoutBuilder(builder: (context, box) {
      _viewport = box.biggest;
      return Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: _view,
              constrained: false,
              minScale: _minScale,
              maxScale: _maxScale,
              boundaryMargin: const EdgeInsets.all(120),
              child: GestureDetector(
                onTapUp: (d) => _tap(d.localPosition),
                child: CustomPaint(
                  size: _geometry.size,
                  painter: _SeatPainter(widget.seats, _geometry,
                      Set.of(widget.selected), widget.enabled, widget.onTap,
                      Theme.of(context).colorScheme),
                ),
              ),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: Column(
              children: [
                IconButton.filledTonal(
                  tooltip: tr('seat.zoomIn'),
                  onPressed: () => _zoom(1.4),
                  icon: const Icon(Icons.zoom_in),
                ),
                IconButton.filledTonal(
                  tooltip: tr('seat.zoomOut'),
                  onPressed: () => _zoom(1 / 1.4),
                  icon: const Icon(Icons.zoom_out),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

class _SeatPainter extends CustomPainter {
  final List<Seat> seats;
  final _Geometry geometry;
  final Set<int> selected;
  final bool Function(Seat) enabled;
  final ValueChanged<Seat> onTap;
  final ColorScheme cs;
  _SeatPainter(this.seats, this.geometry, this.selected, this.enabled,
      this.onTap, this.cs);

  static const _radius = SeatGrid.spacing * 0.42;

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in geometry.rowLabels.entries) {
      _text(canvas, e.key, e.value, 12, Colors.grey.shade700);
    }
    final fill = Paint();
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.lightBlue.shade700;
    for (var i = 0; i < seats.length; i++) {
      final s = seats[i];
      final c = geometry.centers[i];
      final isSelected = selected.contains(s.id);
      final style = _SeatStyle.of(s.status);
      canvas.drawCircle(
          c, _radius, fill..color = isSelected ? cs.primary : style.color);
      if (s.accessible) canvas.drawCircle(c, _radius, ring);
      _text(
          canvas,
          isSelected
              ? '✓'
              : style.symbol.isEmpty
                  ? '${s.number}'
                  : style.symbol,
          c,
          11,
          isSelected ? cs.onPrimary : Colors.black);
    }
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) => [
        for (var i = 0; i < seats.length; i++)
          CustomPainterSemantics(
            rect: Rect.fromCircle(center: geometry.centers[i], radius: _radius),
            properties: SemanticsProperties(
              button: enabled(seats[i]),
              selected: selected.contains(seats[i].id),
              textDirection: TextDirection.ltr,
              label: [
                tr('seat.rowSeat',
                    {'row': seats[i].row, 'n': seats[i].number}),
                tr(_SeatStyle.of(seats[i].status).labelKey),
                if (seats[i].accessible) tr('seat.accessible'),
              ].join(', '),
              onTap: enabled(seats[i]) ? () => onTap(seats[i]) : null,
            ),
          ),
      ];

  @override
  bool shouldRepaint(_SeatPainter old) => true;

  @override
  bool shouldRebuildSemantics(_SeatPainter old) => true;
}
