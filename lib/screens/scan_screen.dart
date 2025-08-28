// lib/screens/scan_screen.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:strefa_ciszy/models/stock_item.dart';
import 'package:strefa_ciszy/screens/inventory_list_screen.dart';
import 'package:strefa_ciszy/services/api_service.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';
import 'add_item_screen.dart';
import 'item_detail_screen.dart';
import 'package:strefa_ciszy/utils/search_utils.dart';

enum ScanPurpose { add, search, projectLine }

class ScanScreen extends StatefulWidget {
  const ScanScreen({
    super.key,
    this.returnCode = false,
    this.purpose = ScanPurpose.add,
    this.titleText,
    this.onScanned,
  });

  final bool returnCode;
  final ScanPurpose purpose;
  final String? titleText;
  final void Function(String code)? onScanned;

  @override
  _ScanScreenState createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    detectionTimeoutMs: 200,
    formats: [BarcodeFormat.ean13, BarcodeFormat.qrCode],
  );

  String? _scannedCode;
  bool _isLoading = false;
  bool? _found;
  bool get _isSearch => widget.purpose == ScanPurpose.search;
  final _kbCtrl = TextEditingController();
  final _kbFocus = FocusNode();

  bool _looksLikeBarcode(String v) => RegExp(r'^\d{6,}$').hasMatch(v);

  final TextEditingController _manualCtrl = TextEditingController();
  List<StockItem> _suggestions = [];
  Timer? _debounce;

  bool get _isPc =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;

  @override
  void initState() {
    super.initState();
    if (_isPc) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _kbFocus.requestFocus(),
      );
    }
  }

  @override
  void dispose() {
    _kbCtrl.dispose();
    _kbFocus.dispose();
    try {
      _controller.dispose();
    } catch (_) {}
    super.dispose();
  }

  void _resetIdle() {
    setState(() {
      _isLoading = false;
      _found = null;
      _scannedCode = null;
    });
  }

  Future<void> _resumeScanner() async {
    if (_isPc) return;
    try {
      await _controller.start();
    } catch (_) {}
  }

  void _onManualChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _refetchSuggestions(v);
    });
  }

  Future<void> _refetchSuggestions(String q) async {
    final query = q.trim();
    if (query.isEmpty) {
      if (mounted) setState(() => _suggestions = []);
      return;
    }

    final isBarcode = RegExp(r'^\d{6,}$').hasMatch(query);
    final tokens = normalize(
      query,
    ).split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    final seedToken = isBarcode
        ? query
        : (tokens..sort((a, b) => b.length.compareTo(a.length))).first;

    final fetchLimit = isBarcode ? 50 : (tokens.length > 1 ? 1000 : 200);
    final results = await ApiService.fetchProducts(
      search: seedToken,
      limit: fetchLimit,
      offset: 0,
    );

    final List<StockItem> filtered = isBarcode
        ? (() {
            final exact = results.where((it) => it.barcode.trim() == query);
            return exact.isNotEmpty ? exact.toList() : results;
          })()
        : results.where((it) {
            return matchesAllTokens(query, [
              it.name,
              it.producent,
              it.category.isNotEmpty ? it.category : it.description,
              it.sku,
              it.barcode,
            ]);
          }).toList();

    if (!mounted) return;
    setState(() => _suggestions = filtered.take(50).toList());
  }

  // void _goToAddItem(String value) {
  //   Navigator.of(context)
  //       .push(
  //         MaterialPageRoute(
  //           builder: (_) => AddItemScreen(
  //             initialBarcode: _looksLikeBarcode(value) ? value : null,
  //             initialName: !_looksLikeBarcode(value) ? value : null,
  //           ),
  //         ),
  //       )
  //       .then((_) async {
  //         if (!mounted) return;
  //         _resetIdle();
  //         await _resumeScanner();
  //       });
  // }

  // Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _findItems(
  //   String raw,
  // ) async {
  //   final col = FirebaseFirestore.instance.collection('stock_items');
  //   final norm = normalize(raw);
  //   final tokens = norm.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);

  //   for (final f in ['barcode', 'sku', 'category']) {
  //     final snap = await col.where(f, isEqualTo: raw).get();
  //     if (snap.docs.isNotEmpty) return snap.docs;
  //   }

  //   final all = await col.get();
  //   return all.docs.where((d) {
  //     final data = d.data();
  //     final candidates = <String?>[
  //       data['name'] as String?,
  //       data['producent'] as String?,
  //       data['sku'] as String?,
  //       data['barcode'] as String?,
  //       data['category'] as String?,
  //     ].map((s) => s != null ? normalize(s) : '').toList();

  //     for (final token in tokens) {
  //       final found = candidates.any((c) => c.contains(token));
  //       if (!found) return false;
  //     }
  //     return true;
  //   }).toList();
  // }

  // api
  Future<List<StockItem>> _findItems(String raw) async {
    final query = raw.trim();
    final isBarcode = _looksLikeBarcode(query);

    final tokens = normalize(
      query,
    ).split(RegExp(r'\s')).where((t) => t.isNotEmpty).toList();
    final isMulti = tokens.length > 1;
    final seedToken = isBarcode
        ? query
        : (tokens.isNotEmpty
              ? (tokens..sort((a, b) => b.length.compareTo(a.length))).first
              : query);
    final fetchLimit = isBarcode ? 50 : (isMulti ? 1000 : 200);

    final results = await ApiService.fetchProducts(
      search: seedToken,
      limit: fetchLimit,
      offset: 0,
    );

    if (isBarcode) {
      final exact = results.where((it) => it.barcode == query).toList();
      if (exact.isNotEmpty) return exact;
    }

    if (tokens.isEmpty) return results;
    return results.where((it) {
      return matchesAllTokens(query, [
        it.name,
        it.producent,
        it.category.isNotEmpty ? it.category : it.description,
        it.sku,
        it.barcode,
      ]);
    }).toList();
  }

  Future<void> _lookupAndHandle(String value) async {
    if (value == _scannedCode && _found != null) return;

    // if (!_isSearch && widget.purpose != ScanPurpose.projectLine) {
    //   _goToAddItem(value);
    //   return;
    // }

    setState(() {
      _scannedCode = value;
      _isLoading = true;
      _found = null;
    });

    try {
      final items = await _findItems(value);

      if (items.isEmpty) {
        if (widget.purpose == ScanPurpose.projectLine) {
          Navigator.of(context).pop();
          return;
        }

        setState(() {
          _isLoading = false;
          _found = false;
        });

        // final add = await showDialog<bool>(
        //   context: context,
        //   builder: (_) => AlertDialog(
        //     title: const Text('Brak produktu'),
        //     content: Text('Nie znaleziono „$value”.\n Dodać nowy produkt?'),
        //     actions: [
        //       TextButton(
        //         onPressed: () => Navigator.pop(context, false),
        //         child: const Text('Nie'),
        //       ),
        //       ElevatedButton(
        //         onPressed: () => Navigator.pop(context, true),
        //         child: const Text('Tak'),
        //       ),
        //     ],
        //   ),
        // );
        // if (!mounted) return;
        // if (add == true) {
        //   _goToAddItem(value);
        // } else {
        //   _resetIdle();
        //   await _resumeScanner();
        // }
        // return;

        /// temp button
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Nie znaleziono „$value” w WAPRO')),
          );
        }
        _resetIdle();
        await _resumeScanner();
        return;
      }
      /////

      final first = items.first;
      final id = first.id;

      if (widget.purpose == ScanPurpose.projectLine) {
        // final data = docs.first.data();
        // final label = [
        //   data['name'] ?? '',
        //   data['producent'] ?? '',
        // ].where((s) => s.isNotEmpty).join(', ');

        final label = [
          first.name,
          first.producent,
        ].where((s) => (s).trim().isNotEmpty).join(', ');

        Navigator.of(context).pop({'id': id, 'label': label});
        return;
      }

      if (items.length == 1) {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => ItemDetailScreen(itemId: id)));
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                InventoryListScreen(isAdmin: true, initialSearch: value),
          ),
        );
      }

      if (!mounted) return;
      _resetIdle();
      await _resumeScanner();
    } catch (_) {
      setState(() {
        _isLoading = false;
        _found = false;
      });
      await _resumeScanner();
    }
  }

  void _onDetect(BarcodeCapture capture) {
    final raw = capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;
    _controller.stop();

    if (widget.returnCode) {
      if (widget.onScanned != null) {
        widget.onScanned!(raw);
      }
      Navigator.of(context).pop(raw);
      return;
    }

    _lookupAndHandle(raw);
  }

  void _onManualEntry(String input) {
    final code = input.trim();
    if (code.isEmpty) return;
    if (!_isPc) _controller.stop();

    if (widget.returnCode) {
      if (widget.onScanned != null) {
        widget.onScanned!(code);
      }
      Navigator.of(context).pop(code);
      return;
    }

    _lookupAndHandle(code);
    if (_isPc) {
      _kbCtrl.clear();
      _kbFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSearch = widget.purpose == ScanPurpose.search;
    final title =
        widget.titleText ?? (isSearch ? 'Wyszukaj produkt' : 'Dodaj produkt');

    return AppScaffold(
      title: title,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
              Expanded(
                child: _isPc
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.qr_code_scanner, size: 72),
                            SizedBox(height: 12),
                            Text('USB scanning (Web)'),
                          ],
                        ),
                      )
                    : MobileScanner(
                        controller: _controller,
                        onDetect: _onDetect,
                      ),
              ),

              if (_isSearch && _isLoading)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),

              if (_isSearch && _found == false)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Nie ma produktu “${_scannedCode ?? ''}”',
                    style: const TextStyle(fontSize: 16, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),

              if (_isSearch && _scannedCode != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Szukam: ${_scannedCode!}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              // ===== Suggest
              if (_suggestions.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: Material(
                    elevation: 2,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _suggestions.length,
                      itemBuilder: (_, i) {
                        final s = _suggestions[i];
                        return ListTile(
                          dense: true,
                          title: Text('${s.name}, ${s.producent}'),
                          subtitle: s.description.isNotEmpty
                              ? Text(s.description)
                              : null,
                          trailing: Text('Stan: ${s.quantity}'),
                          onTap: () {
                            _kbCtrl.text = s.barcode;
                            _kbCtrl.selection = TextSelection.fromPosition(
                              TextPosition(offset: _kbCtrl.text.length),
                            );
                            setState(() => _suggestions = []);
                          },
                        );
                      },
                    ),
                  ),
                ),

              // ===== Manual
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: TextField(
                  controller: _kbCtrl,
                  focusNode: _kbFocus,
                  autofocus: _isPc,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    labelText: 'skanuj kod (USB) lub wpisz…',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (v) {
                    final query = v.trim();
                    if (query.isNotEmpty) {
                      Navigator.of(context).pop<String>(query);
                    }
                  },
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                ),
              ),

              // (kept commented block unchanged)
              // if (_found == false && !_isSearch)
              //   Padding(
              //     padding: EdgeInsets.fromLTRB(
              //       16, 8, 16, MediaQuery.of(context).viewPadding.bottom + 16,
              //     ),
              //     child: ElevatedButton(
              //       onPressed: () {
              //         Navigator.of(context).push(
              //           MaterialPageRoute(
              //             builder: (_) => AddItemScreen(initialBarcode: _scannedCode),
              //           ),
              //         );
              //       },
              //       child: const Text('Dodaj Nowy Produkt'),
              //     ),
              //   ),
            ],
          ),
        ),
      ),
    );
  }
}
