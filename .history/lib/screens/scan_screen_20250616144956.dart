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
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 200,
    formats: [BarcodeFormat.ean13, BarcodeFormat.qrCode],
  );

  String? _scannedCode;
  bool _isLoading = false;
  bool? _found;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _lookupCode(String code) {
    if (code == _scannedCode && _found != null) return;

    setState(() {
      _scannedCode = code;
      _isLoading = true;
      _found = null;
    });

    FirebaseFirestore.instance
        .collection('stock_items')
        .where('barcode', isEqualTo: code)
        .limit(1)
        .get()
        .then((snap) {
          if (snap.docs.isNotEmpty) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => ItemDetailScreen(code: code)),
            );
          } else {
            setState(() {
              _isLoading = false;
              _found = false;
            });
          }
        })
        .catchError((e) {
          setState(() {
            _isLoading = false;
            _found = false;
          });
        });
  }

  void _onDetect(BarcodeCapture capture) {
    final raw = capture.barcodes.first.rawValue;
    if (raw != null && raw.isNotEmpty) {
      _lookupCode(raw);
    }
  }

  void _onManualEntry(String input) {
    final code = input.trim();
    if (code.isNotEmpty) {
      _lookupCode(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Szukaj towar')),
      body: SafeArea(
        child: Column(
          children: [
            // 1) Live camera
            Expanded(
              flex: 1,
              child: MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
              ),
            ),

            if (_isLoading)
              Padding(
                padding: const EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),

            if (_found == false)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Nie ma takiego produktu “$_scannedCode”',
                  style: TextStyle(fontSize: 16, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),

            if (_scannedCode != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Skanowany: $_scannedCode',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),

            // Manual entry
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'Ręcznie szukać po nazwie lub kodu...',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: _onManualEntry,
              ),
            ),

            if (_found == false)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  MediaQuery.of(context).viewPadding.bottom + 16,
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            AddItemScreen(initialBarcode: _scannedCode),
                      ),
                    );
                  },
                  child: Text('Dodaj Nowy Produkt'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
