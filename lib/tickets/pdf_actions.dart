import 'dart:typed_data';
import 'dart:ui';
import 'package:printing/printing.dart';

class TicketPdfActions {
  final Uint8List bytes;
  final String name;
  TicketPdfActions(this.bytes, this.name);

  bool get canDownload => false;
  Future<void> download() => throw UnsupportedError('download');

  Future<bool> canShare() async => (await Printing.info()).canShare;
  Future<void> share(Rect bounds) async {
    await Printing.sharePdf(bytes: bytes, filename: name, bounds: bounds);
  }
}
