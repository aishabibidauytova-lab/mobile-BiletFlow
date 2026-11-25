import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

/// Hands a downloaded file to the system share sheet (a download in browsers).
Future<void> shareFile(
    BuildContext context, List<int> bytes, String name, String mimeType) async {
  // Tablets anchor the share sheet to the widget that asked for it.
  final box = context.findRenderObject() as RenderBox?;
  final origin =
      box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  await SharePlus.instance.share(ShareParams(
    files: [XFile.fromData(Uint8List.fromList(bytes), mimeType: mimeType)],
    fileNameOverrides: [name],
    sharePositionOrigin: origin,
  ));
}
