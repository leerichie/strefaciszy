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
    // Only fire once per unique code, then wait `detectionTimeoutMs`
    detectionSpeed: DetectionSpeed.noDuplicates,
    detectionTimeoutMs: 800,
    // Scan both barcodes and QR codes
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
    if (_scannedCode == null) return;
    Navigator.of(context).pop(_scannedCode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Scan or Enter Code')),
      body: Column(
        children: [
          // 1) Live camera scanner (2/3 of screen)
          Expanded(
            flex: 2,
            child: MobileScanner(controller: _controller, onDetect: _onDetect),
          ),

          // 2) Display the scanned/fallback code
          if (_scannedCode != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Code: $_scannedCode',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

          // 3) Manual entry fallback
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

          // 4) Lookup/Continue button
          Padding(
            padding: const EdgeInsets.all(10),
            child: ElevatedButton(
              onPressed: _scannedCode == null ? null : _onLookup,
              child: Text('Lookup Product'),
            ),
          ),
        ],
      ),
    );
  }
}
