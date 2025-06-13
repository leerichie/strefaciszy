// lib/screens/scan_screen.dart

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'add_item_screen.dart';
import 'item_detail_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  _ScanScreenState createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 200,
    formats: [BarcodeFormat.ean13, BarcodeFormat.qrCode],
  );

  String? _scannedCode;
  Future<QuerySnapshot>? _lookupFuture;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startLookup(String code) {
    setState(() {
      _scannedCode = code;
      _lookupFuture = FirebaseFirestore.instance
          .collection('stock_items')
          .where('barcode', isEqualTo: code)
          .limit(1)
          .get();
    });
  }

  void _onDetect(BarcodeCapture capture) {
    final raw = capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;
    // only start a new lookup if code changed
    if (raw != _scannedCode) {
      _startLookup(raw);
    }
  }

  void _onManualEntry(String code) {
    final trimmed = code.trim();
    if (trimmed.isEmpty || trimmed == _scannedCode) return;
    _startLookup(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Scan or Enter Code')),
      body: SafeArea(
        child: _lookupFuture == null
            // 1) Initial scanner + manual entry
            ? Column(
                children: [
                  Expanded(
                    flex: 2,
                    child: MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                    ),
                  ),
                  if (_scannedCode != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Scanned: $_scannedCode',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Or enter code manually',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: _onManualEntry,
                    ),
                  ),
                  SizedBox(height: 24),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      MediaQuery.of(context).viewPadding.bottom + 16,
                    ),
                    child: ElevatedButton(
                      onPressed: _scannedCode == null
                          ? null
                          : () => _startLookup(_scannedCode!),
                      child: Text('Lookup Product'),
                    ),
                  ),
                ],
              )
            // 2) Lookup in progress / result
            : FutureBuilder<QuerySnapshot>(
                future: _lookupFuture,
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }
                  final docs = snap.data!.docs;
                  // 2a) Not found
                  if (docs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Product not found for\n“$_scannedCode”',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18),
                          ),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => AddItemScreen(
                                    initialBarcode: _scannedCode,
                                  ),
                                ),
                              );
                            },
                            child: Text('Add New Product'),
                          ),
                          SizedBox(height: 12),
                          TextButton(
                            onPressed: () {
                              // reset and scan again
                              setState(() {
                                _scannedCode = null;
                                _lookupFuture = null;
                              });
                            },
                            child: Text('Try Again'),
                          ),
                        ],
                      ),
                    );
                  }

                  // 2b) Found → navigate to detail
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => ItemDetailScreen(code: _scannedCode!),
                      ),
                    );
                  });
                  return Center(child: CircularProgressIndicator());
                },
              ),
      ),
    );
  }
}
