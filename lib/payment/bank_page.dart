import 'dart:convert';
import '../l10n/l10n.dart';
import '../models/models.dart';

class BankPage {
  final String html;
  final Set<Uri> returnUrls;
  BankPage._(this.html, this.returnUrls);

  factory BankPage.fromSession(Map<String, dynamic> session) {
    const scripts = {
      'https://test-epay.epayment.kz/payform/payment-api.js',
      'https://epay.homebank.kz/payform/payment-api.js',
    };
    final script = session['scriptUrl'];
    final payment = session['payment'];
    if (!scripts.contains(script) || payment is! Map || payment.isEmpty) {
      throw ApiException(tr('bank.invalid'));
    }
    // Keep the JSON inside the script element, including buyer-provided text.
    final data = jsonEncode(payment).replaceAll('<', r'\u003c');
    final error = const HtmlEscape().convert(tr('bank.failed'));
    final html =
        '''<!doctype html><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<p id="message">${tr('bank.loading')}</p>
<script>
const script = document.createElement('script');
const fail = () => { document.getElementById('message').textContent = '$error'; };
const timer = setTimeout(() => { script.onload = null; fail(); }, 20000);
script.src = '$script';
script.onerror = () => { clearTimeout(timer); fail(); };
script.onload = () => {
  clearTimeout(timer);
  try { window.halyk.pay($data); } catch (_) { fail(); }
};
document.head.appendChild(script);
</script>''';
    final returns = <Uri>{};
    for (final key in ['backLink', 'failureBackLink']) {
      final value = payment[key];
      final uri = value is String ? Uri.tryParse(value) : null;
      if (uri != null && uri.hasAuthority) returns.add(uri);
    }
    return BankPage._(html, returns);
  }
}
