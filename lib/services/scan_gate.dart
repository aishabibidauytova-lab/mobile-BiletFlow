/// Decides which camera readings count as a new scan.
///
/// A code held in front of the camera is read many times a second but is one
/// scan. Once it has been out of view for [gap], showing it again is a new
/// scan, so a used ticket is reported as already used.
class ScanGate {
  final Duration gap;
  final DateTime Function() _now;
  String? _code;
  DateTime? _seen;

  ScanGate({this.gap = const Duration(seconds: 2), DateTime Function()? now})
      : _now = now ?? DateTime.now;

  /// Call for every reading. [busy] is true while a result is still on screen:
  /// nothing new is accepted then.
  bool accept(String code, {bool busy = false}) {
    final now = _now();
    if (code == _code && now.difference(_seen!) < gap) {
      _seen = now;
      return false;
    }
    if (busy) return false;
    _code = code;
    _seen = now;
    return true;
  }
}
