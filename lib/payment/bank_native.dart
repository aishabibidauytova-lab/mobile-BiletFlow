import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../l10n/l10n.dart';
import 'bank_page.dart';

Future<void> openBank(BuildContext context, BankPage page) async {
  await Navigator.of(
    context,
  ).push<void>(MaterialPageRoute(builder: (_) => _BankScreen(page: page)));
}

class _BankScreen extends StatefulWidget {
  final BankPage page;
  const _BankScreen({required this.page});

  @override
  State<_BankScreen> createState() => _BankState();
}

class _BankState extends State<_BankScreen> {
  WebViewController? _controller;
  bool _failed = false;
  bool _returning = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (request.isMainFrame &&
                uri != null &&
                widget.page.returnUrls.any(
                  (u) =>
                      u.scheme == uri.scheme &&
                      u.authority == uri.authority &&
                      u.path == uri.path,
                )) {
              if (mounted && !_returning) {
                _returning = true;
                Navigator.pop(context);
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );
      await controller.loadHtmlString(widget.page.html);
      if (mounted) setState(() => _controller = controller);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Halyk')),
    body: SafeArea(
      child: _failed
          ? Center(child: Text(tr('bank.failed')))
          : _controller == null
          ? const Center(child: CircularProgressIndicator())
          : WebViewWidget(controller: _controller!),
    ),
  );
}
