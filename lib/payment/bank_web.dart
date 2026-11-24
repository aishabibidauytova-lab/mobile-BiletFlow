import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../l10n/l10n.dart';
import 'bank_page.dart';

// Open a separate tab on a user gesture. The order screen stays signed in.
Future<void> openBank(BuildContext context, BankPage page) async {
  final url = web.URL.createObjectURL(
    web.Blob(
      [page.html.toJS].toJS,
      web.BlobPropertyBag(type: 'text/html;charset=utf-8'),
    ),
  );
  bool opened = false;
  try {
    await showDialog<void>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (_, update) => AlertDialog(
          title: const Text('Halyk'),
          content: Text(tr(opened ? 'bank.return' : 'bank.open')),
          actions: [
            if (!opened)
              TextButton(
                onPressed: () {
                  web.window.open(url, '_blank', 'noopener,noreferrer');
                  update(() => opened = true);
                },
                child: Text(tr('bank.open')),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: Text(tr(opened ? 'order.checkPayment' : 'no')),
            ),
          ],
        ),
      ),
    );
  } finally {
    web.URL.revokeObjectURL(url);
  }
}
