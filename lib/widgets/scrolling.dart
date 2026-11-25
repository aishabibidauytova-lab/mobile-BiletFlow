import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// App-wide scrolling: no stretch effect at the ends of a list, and lists can
/// be dragged with any pointer, including a mouse.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();

  @override
  Widget buildOverscrollIndicator(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;
}

/// A horizontal list that a mouse wheel (up and down) also moves sideways.
class HorizontalStrip extends StatefulWidget {
  final EdgeInsetsGeometry padding;
  final List<Widget> children;
  const HorizontalStrip(
      {super.key, this.padding = EdgeInsets.zero, required this.children});

  @override
  State<HorizontalStrip> createState() => _HorizontalStripState();
}

class _HorizontalStripState extends State<HorizontalStrip> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_controller.hasClients) return;
    final delta = event.scrollDelta;
    // Sideways scrolling is already handled by the list itself.
    if (delta.dx != 0 || delta.dy == 0) return;
    final position = _controller.position;
    final target = (position.pixels + delta.dy)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    // At either end the page behind scrolls as usual.
    if (target == position.pixels) return;
    GestureBinding.instance.pointerSignalResolver
        .register(event, (_) => _controller.jumpTo(target));
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerSignal: _onSignal,
        child: ListView(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          padding: widget.padding,
          children: widget.children,
        ),
      );
}
