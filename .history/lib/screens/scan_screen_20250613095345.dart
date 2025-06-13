// lib/screens/scan_screen.dart

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanScreen extends StatelessWidget {
  final MobileScannerController controller = MobileScannerController(
    // instead of `allowDuplicates: false`, do this:
    detectionSpeed: DetectionSpeed.noDuplicates, // ← no duplicate scans
    detectionTimeoutMs:
        800, // optional: wait 800ms before scanning the same code again
    formats: [
      BarcodeFormat.ean13,
      BarcodeFormat.qrCode,
    ], // your allowed formats
    torchEnabled: false,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Scan Barcode/QR')),
      body: Column(
        children: [
          // 1) Camera preview (takes 2/3 of height)
          Expanded(
            flex: 2,
            child: MobileScanner(
              allowDuplicates: false,
              onDetect: (capture) {
                if (_scanned) return; // prevent multiple triggers
                final bar = capture.barcodes.first.rawValue;
                setState(() {
                  _scannedCode = bar;
                  _scanned = true;
                });
              },
            ),
          ),

          // 2) Show the scanned code, if any
          if (_scannedCode != null) ...[
            Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Scanned code: $_scannedCode',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],

          // 3) Manual entry fallback
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Enter code manually',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) {
                if (v.trim().isEmpty) return;
                setState(() {
                  _scannedCode = v.trim();
                  _scanned = true;
                });
              },
            ),
          ),

          // 4) Continue button
          Padding(
            padding: EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _scannedCode == null
                  ? null
                  : () {
                      // TODO: lookup _scannedCode in Firestore
                      Navigator.of(context).pop(_scannedCode);
                    },
              child: Text('Lookup Product'),
            ),
          ),
        ],
      ),
    );
  }
}
