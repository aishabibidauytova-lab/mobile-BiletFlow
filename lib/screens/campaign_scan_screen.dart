import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../l10n/l10n.dart';
import '../services/campaign_link.dart';

/// Camera for Campaign QR codes. Pops with the [CampaignLink] that was read.
/// Admission tickets are scanned elsewhere (check-in).
class CampaignScanScreen extends StatefulWidget {
  const CampaignScanScreen({super.key});

  @override
  State<CampaignScanScreen> createState() => _CampaignScanScreenState();
}

class _CampaignScanScreenState extends State<CampaignScanScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _done = false;
  bool _wrongCode = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done || capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null) return;
    final link = CampaignLink.parse(raw);
    if (link == null) {
      setState(() => _wrongCode = true);
      return;
    }
    _done = true;
    Navigator.pop(context, link);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(tr('link.scan'))),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(tr('scan.noCamera'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white)),
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.all(20),
            child: SafeArea(
              top: false,
              child: Text(
                tr(_wrongCode ? 'link.notCampaign' : 'link.scanHint'),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
