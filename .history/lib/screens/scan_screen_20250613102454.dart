// lib/screens/scan_screen.dart

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  _ScanScreenState createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    detectionTimeoutMs: 800,
    formats: [BarcodeFormat.ean13, BarcodeFormat.qrCode],
  );

  String? _scannedCode;
  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;
    setState(() {
      _scannedCode = raw;
      _hasScanned = true;
    });
  }

  void _onManualEntry(String code) {
    if (code.trim().isEmpty) return;
    setState(() {
      _scannedCode = code.trim();
      _hasScanned = true;
    });
  }

  void _onLookup() {
    Navigator.of(context).pop(_scannedCode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Scan or Enter Code')),
      // Wrap entire column in SafeArea so nothing is hidden
      body: SafeArea(
        child: Column(
          children: [
            // Scanner preview
            Expanded(
              flex: 2,
              child: MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
              ),
            ),

            // Show scanned code
            if (_scannedCode != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Code: $_scannedCode',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),

            // Manual entry fallback
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'Or enter code manually',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: _onManualEntry,
              ),
            ),

            // Push button to the bottom but inside SafeArea
            Spacer(),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.of(context).viewPadding.bottom + 16,
              ),
              child: ElevatedButton(
                onPressed: _scannedCode == null ? null : _onLookup,
                child: Text('Lookup Product'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
