import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'dart:ui';
import 'package:web/web.dart' as web;

class TicketPdfActions {
  final web.File file;
  final String name;
  TicketPdfActions(Uint8List bytes, this.name)
    : file = web.File(
        [bytes.toJS].toJS,
        name,
        web.FilePropertyBag(type: 'application/pdf'),
      );

  bool get canDownload => true;

  Future<void> download() async {
    final url = web.URL.createObjectURL(file);
    final link = web.HTMLAnchorElement()
      ..href = url
      ..download = name;
    try {
      web.document.body!.append(link);
      link.click();
    } finally {
      link.remove();
      Timer(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
    }
  }

  web.ShareData get _data => web.ShareData(files: [file].toJS);

  Future<bool> canShare() async {
    final nav = web.window.navigator;
    return nav.has('canShare') && nav.has('share') && nav.canShare(_data);
  }

  Future<void> share(Rect bounds) async {
    final promise = web.window.navigator.share(_data);
    // A dismissed system sheet rejects with AbortError.
    final handled = promise.callMethod<JSPromise<JSAny?>>(
      'catch'.toJS,
      ((JSObject error) {
        if (error.getProperty<JSString?>('name'.toJS)?.toDart != 'AbortError') {
          throw StateError('File sharing failed');
        }
      }).toJS,
    );
    await handled.toDart;
  }
}
