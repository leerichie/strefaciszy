// lib/screens/scan_screen.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:strefa_ciszy/models/stock_item.dart';
import 'package:strefa_ciszy/services/admin_api.dart';
import 'package:strefa_ciszy/services/api_service.dart';
import 'package:strefa_ciszy/screens/item_detail_screen.dart';
import 'package:strefa_ciszy/utils/web_fullscreen_guard_stub.dart'
    if (dart.library.js_interop) 'package:strefa_ciszy/utils/web_fullscreen_guard_web.dart'
    as webfs;
import 'package:strefa_ciszy/widgets/app_scaffold.dart';

enum ScanPurpose { add, search, projectLine, eanForItem }

class ScanScreen extends StatefulWidget {
  const ScanScreen({
    super.key,
    this.returnCode = false,
    this.purpose = ScanPurpose.search,
    this.titleText,
    this.onScanned,
    this.setEanForItemId,
    this.setEanForItemLabel,
  });

  final bool returnCode;
  final ScanPurpose purpose;
  final String? titleText;
  final void Function(String code)? onScanned;
  final String? setEanForItemId;
  final String? setEanForItemLabel;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool get _isDesktopLike =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  bool get _isProjectLine => widget.purpose == ScanPurpose.projectLine;
  bool get _isSearch => widget.purpose == ScanPurpose.search;
  bool get _isSetEan => widget.purpose == ScanPurpose.eanForItem;

  final MobileScannerController _cam = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    detectionTimeoutMs: 250,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.code128,
      BarcodeFormat.code93,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.qrCode,
    ],
  );

  final FocusNode _rawFocus = FocusNode();
  StringBuffer _kbBuffer = StringBuffer();
  Timer? _kbIdleTimer;

  String? _lastValue;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _busy = false;

  bool _torchOn = false;
  String? _statusText;

  @override
  void initState() {
    super.initState();

    if (kIsWeb) webfs.initFullscreenGuard();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _unfocusAll();
      if (_isDesktopLike) {
        FocusScope.of(context).requestFocus(_rawFocus);
      }
    });
  }

  @override
  void dispose() {
    _kbIdleTimer?.cancel();
    _rawFocus.dispose();
    _cam.dispose();

    if (kIsWeb) webfs.disposeFullscreenGuard();
    super.dispose();
  }

  static String _digitsOnly(String s) {
    final b = StringBuffer();
    for (final r in s.runes) {
      if (r >= 48 && r <= 57) b.writeCharCode(r);
    }
    return b.toString();
  }

  static String? _upcToEan13(String d) => d.length == 12 ? '0$d' : null;

  bool _debounced(String v) {
    final now = DateTime.now();
    if (v == _lastValue && now.difference(_lastAt).inMilliseconds < 900) {
      return true;
    }
    _lastValue = v;
    _lastAt = now;
    return false;
  }

  Future<void> _resumeCamera() async {
    if (_isDesktopLike) return;
    try {
      await _cam.start();
    } catch (_) {}
  }

  void _showSnack(String msg, {Duration? forTime}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: forTime ?? const Duration(seconds: 2),
      ),
    );
  }

  void _showRootSnack(String msg, {Duration? forTime}) {
    final rootCtx = Navigator.of(context, rootNavigator: true).context;
    ScaffoldMessenger.of(rootCtx).clearSnackBars();
    ScaffoldMessenger.of(rootCtx).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: forTime ?? const Duration(milliseconds: 1100),
      ),
    );
  }

  void _unfocusAll() {
    try {
      FocusManager.instance.primaryFocus?.unfocus();
      final rootCtx = Navigator.of(context, rootNavigator: true).context;
      FocusScope.of(rootCtx).unfocus();
    } catch (_) {}
  }

  bool _isExactEanMatch(String code, String candidate) {
    final a = _digitsOnly(code);
    final b = _digitsOnly(candidate);
    if (a.isEmpty || b.isEmpty) return false;

    if (a == b) return true;

    // Accept UPC-A <-> EAN-13 equivalents
    final aAsEan13 = _upcToEan13(a); // 12 -> 13
    final bAsEan13 = _upcToEan13(b);
    if (aAsEan13 != null && aAsEan13 == b) return true;
    if (bAsEan13 != null && bAsEan13 == a) return true;

    return false;
  }

  Future<void> _notFoundReset(String norm) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Nie znaleziono „$norm”.'),
        duration: const Duration(milliseconds: 1100),
      ),
    );

    setState(() => _statusText = null);
    _busy = false;

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    if (_isDesktopLike) {
      FocusScope.of(context).requestFocus(_rawFocus);
    } else {
      await _resumeCamera();
    }
  }

  Future<void> _handleRawScan(String raw) async {
    if (_busy) return;

    final digits = _digitsOnly(raw);
    if (digits.length < 8) return;

    final norm = digits;
    final alt13 = _upcToEan13(norm);
    if (_debounced(norm)) return;

    _busy = true;
    // setState(() => _statusText = 'Szukam: $norm');
    setState(
      () => _statusText = _isSetEan ? 'Ustawiam EAN: $norm' : 'Szukam: $norm',
    );

    // set EAN
    if (_isSetEan) {
      final itemId = widget.setEanForItemId;
      if (itemId == null || itemId.isEmpty) {
        _showRootSnack('Brak ID dla EAN.', forTime: const Duration(seconds: 2));
        if (mounted) Navigator.of(context).pop();
        return;
      }

      final eanToSet = alt13 ?? norm;
      if (!(eanToSet.length == 13 || eanToSet.length == 8)) {
        _showRootSnack(
          'Nieprawidłowy EAN: $eanToSet',
          forTime: const Duration(seconds: 2),
        );
        if (mounted) {
          _busy = false;
          await _resumeCamera();
        }
        return;
      }

      try {
        final res = await AdminApi.setEanWithResult(
          productId: itemId,
          ean: eanToSet,
        );
        if (res.ok) {
          _showRootSnack(
            'Zapisano EAN: $eanToSet',
            forTime: const Duration(seconds: 2),
          );
          if (mounted) {
            Navigator.of(context).pop(<String, dynamic>{
              'mode': 'setEan',
              'ok': true,
              'ean': eanToSet,
            });
          }
          return;
        }

        if (res.duplicate) {
          final who = res.conflictName?.trim().isNotEmpty == true
              ? res.conflictName!
              : (res.conflictId ?? 'inny produkt');
          _showRootSnack(
            'Ten EAN już istnieje: $who',
            forTime: const Duration(seconds: 3),
          );
          if (mounted) {
            Navigator.of(context).pop(<String, dynamic>{
              'mode': 'setEan',
              'ok': false,
              'duplicate': true,
              'ean': eanToSet,
              'conflictId': res.conflictId,
              'conflictName': res.conflictName,
            });
          }
          return;
        }

        if (res.error == 'already-set' || res.error == 'already-set-race') {
          _showRootSnack(
            'Produkt ma już EAN.',
            forTime: const Duration(seconds: 2),
          );
          if (mounted)
            Navigator.of(context).pop(<String, dynamic>{
              'mode': 'setEan',
              'ok': false,
              'already': true,
            });
          return;
        }

        _showRootSnack(
          'Błąd zapisu: ${res.error ?? 'nieznany'}',
          forTime: const Duration(seconds: 2),
        );
        if (mounted)
          Navigator.of(context).pop(<String, dynamic>{
            'mode': 'setEan',
            'ok': false,
            'error': res.error ?? 'unknown',
          });
        return;
      } catch (e) {
        _showRootSnack('Błąd: $e', forTime: const Duration(seconds: 2));
        if (mounted)
          Navigator.of(context).pop(<String, dynamic>{
            'mode': 'setEan',
            'ok': false,
            'error': e.toString(),
          });
        return;
      }
    }

    try {
      final items = await ApiService.fetchProducts(
        search: norm,
        limit: 50,
        offset: 0,
      );

      StockItem? exact;
      final candidates = <StockItem>[];

      for (final it in items) {
        final bc = it.barcode;
        if (bc.trim().isEmpty) continue;

        if (_isExactEanMatch(norm, bc)) {
          exact ??= it;
        } else {
          final bcd = _digitsOnly(bc);
          if (bcd.contains(norm) || norm.contains(bcd)) {
            candidates.add(it);
          }
        }
      }

      // if (widget.returnCode) {
      //   if (exact != null) {
      //     widget.onScanned?.call(norm);
      //     _kbIdleTimer?.cancel();
      //     _kbBuffer = StringBuffer();
      //     _unfocusAll();
      //     if (!mounted) return;
      //     Navigator.of(context).pop(norm);
      //   } else {
      //     _showRootSnack('Nie znaleziono „$norm”.');
      //     _kbIdleTimer?.cancel();
      //     _kbBuffer = StringBuffer();
      //     await Future.delayed(const Duration(seconds: 1));
      //     _unfocusAll();
      //     if (!mounted) return;
      //     Navigator.of(context).pop();
      //   }
      //   return;
      // }
      if (widget.returnCode) {
        final eanToReturn =
            alt13 ?? norm; // normalize UPC-A -> EAN-13 if needed
        widget.onScanned?.call(eanToReturn);
        _kbIdleTimer?.cancel();
        _kbBuffer = StringBuffer();
        _unfocusAll();
        if (!mounted) return;
        Navigator.of(context).pop(eanToReturn);
        return;
      }

      if (_isProjectLine) {
        if (exact != null) {
          final label = [
            exact!.name,
            if (exact!.producent.isNotEmpty) exact!.producent,
          ].where((e) => e.trim().isNotEmpty).join(', ');

          if (!mounted) return;
          Navigator.of(context).pop({'id': exact!.id, 'label': label});
          return;
        }

        _showRootSnack('Nie znaleziono „$norm”.');
        _kbIdleTimer?.cancel();
        _kbBuffer = StringBuffer();
        await Future.delayed(const Duration(seconds: 2));
        _unfocusAll();
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      }

      if (_isSearch) {
        if (exact != null) {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ItemDetailScreen(itemId: exact!.id),
            ),
          );
          return;
        }

        await _notFoundReset(norm);
        return;
      }

      await _notFoundReset(norm);
      return;
    } catch (e) {
      if (mounted) {
        _showSnack('Błąd skanowania: $e');
        setState(() => _statusText = null);
      }
      _busy = false;
      await _resumeCamera();
    }
  }

  Future<void> _showChooser(
    List<StockItem> items, {
    required String scannedNorm,
  }) async {
    if (!mounted) return;
    if (items.isEmpty) {
      _showSnack('Nie znaleziono „$scannedNorm”.');
      _busy = false;
      await _resumeCamera();
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 500),
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final it = items[i];
                final qtyText =
                    '${it.quantity}${it.unit.isNotEmpty ? ' ${it.unit}' : ''}';
                return ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text(
                    it.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (it.producent.isNotEmpty) Text(it.producent),
                      Row(
                        children: [
                          if (it.sku.isNotEmpty)
                            Flexible(
                              child: Text(
                                'SKU: ${it.sku}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          if (it.sku.isNotEmpty) const SizedBox(width: 12),
                          if (it.barcode.isNotEmpty)
                            Flexible(
                              child: Text(
                                'EAN: ${it.barcode}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Text(
                    qtyText,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: it.quantity <= 0
                          ? Colors.red
                          : it.quantity <= 3
                          ? Colors.orange
                          : Colors.green,
                    ),
                  ),
                  onTap: () {
                    final label = [
                      it.name,
                      if (it.producent.isNotEmpty) it.producent,
                    ].where((e) => e.trim().isNotEmpty).join(', ');
                    Navigator.of(context).pop();
                    Navigator.of(context).pop({'id': it.id, 'label': label});
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _onDetect(BarcodeCapture cap) {
    final first = cap.barcodes.isNotEmpty ? cap.barcodes.first : null;
    final raw = first?.rawValue;
    if (raw == null || raw.isEmpty) return;

    _cam.stop();
    _handleRawScan(raw);
  }

  void _onRawKey(RawKeyEvent e) {
    if (!_isDesktopLike) return;

    if (!_rawFocus.hasFocus) {
      FocusScope.of(context).requestFocus(_rawFocus);
    }

    final isDown = e is RawKeyDownEvent;
    if (!isDown) return;

    String? ch;
    if (e is RawKeyDownEvent && e.data is RawKeyEventDataWeb) {
      ch = (e.data as RawKeyEventDataWeb).keyLabel;
    } else {
      ch = e.character;
    }

    final logical = e.logicalKey;
    final isEnter =
        logical == LogicalKeyboardKey.enter ||
        logical == LogicalKeyboardKey.numpadEnter;
    final isTab = logical == LogicalKeyboardKey.tab;

    if (isEnter || isTab) {
      _kbIdleTimer?.cancel();
      final v = _kbBuffer.toString();
      _kbBuffer = StringBuffer();
      if (v.isNotEmpty) _handleRawScan(v);
      return;
    }

    if (ch != null && ch.isNotEmpty) {
      final rune = ch.codeUnitAt(0);
      final isDigit = rune >= 48 && rune <= 57;
      if (isDigit) {
        _kbBuffer.write(ch);
        _kbIdleTimer?.cancel();
        _kbIdleTimer = Timer(const Duration(milliseconds: 120), () {
          final v = _kbBuffer.toString();
          _kbBuffer = StringBuffer();
          if (v.isNotEmpty) _handleRawScan(v);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.titleText ??
        (_isSetEan
            ? 'Skanuj EAN (ustaw)'
            : (_isProjectLine
                  ? 'Skanuj (dodaj do projektu)'
                  : 'Skanuj (sprawdz towar)'));

    return AppScaffold(
      title: title,
      body: SafeArea(
        child: Stack(
          children: [
            if (!_isDesktopLike)
              Positioned.fill(
                child: MobileScanner(controller: _cam, onDetect: _onDetect),
              )
            else
              Align(
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 640,
                    maxHeight: 380,
                  ),
                  child: Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: RawKeyboardListener(
                        autofocus: true,
                        focusNode: _rawFocus,
                        onKey: _onRawKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.qr_code_scanner, size: 56),
                            const SizedBox(height: 10),
                            Text(
                              _isSetEan
                                  ? (widget.setEanForItemLabel?.isNotEmpty ==
                                            true
                                        ? 'Ustaw EAN dla: ${widget.setEanForItemLabel}'
                                        : 'Ustaw EAN…')
                                  : 'Skanuj...',
                            ),
                            if (_statusText != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _statusText!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            if (!_isDesktopLike)
              Positioned(
                right: 12,
                top: 12,
                child: Column(
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'torch',
                      onPressed: () async {
                        _torchOn = !_torchOn;
                        await _cam.toggleTorch();
                        if (mounted) setState(() {});
                      },
                      child: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
                    ),
                    const SizedBox(height: 12),
                    _SwitchCamBtn(controller: _cam),
                  ],
                ),
              ),
            if (_isSearch && _statusText != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  color: Colors.black.withValues(alpha: 0.5),
                  child: Text(
                    _statusText!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SwitchCamBtn extends StatelessWidget {
  const _SwitchCamBtn({required this.controller});
  final MobileScannerController controller;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'camera',
      onPressed: () async {
        await controller.switchCamera();
      },
      child: const Icon(Icons.cameraswitch),
    );
  }
}
