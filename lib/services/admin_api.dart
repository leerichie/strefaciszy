// lib/services/admin_api.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:strefa_ciszy/models/stock_item.dart';
import 'package:strefa_ciszy/services/api_service.dart';

class SetEanResult {
  final bool ok;
  final String? error;
  final String? conflictId;
  final String? conflictName; // NEW: friendly name for duplicate target
  final String? current;
  final bool duplicate; // NEW: explicit flag

  const SetEanResult({
    required this.ok,
    this.error,
    this.conflictId,
    this.conflictName,
    this.current,
    this.duplicate = false,
  });
}

class AdminApi {
  static const List<String> _primaryCandidates = [
    // If you later expose HTTPS on 9104, add it here.
    // 'https://wapro-api.tail52a6fb.ts.net:9104/api',
  ];

  static const List<String> _fallbacks = [
    // MagicDNS inside tailnet
    'http://wapro-api:9104/api',
    // Tailscale IP
    'http://100.86.227.1:9104/api',
    // LAN
    'http://192.168.1.103:9104/api',
    // Android emulator -> host
    'http://10.0.2.2:9104/api',
  ];

  static String _base = '';

  static Future<void> init() async {
    final candidates = <String>[..._primaryCandidates, ..._fallbacks];

    for (final b in candidates) {
      try {
        final r = await http
            .get(Uri.parse('$b/admin/health'))
            .timeout(const Duration(seconds: 3));
        if (r.statusCode == 200) {
          _base = b;
          debugPrint('[AdminApi] BASE = $_base');
          return;
        }
      } catch (_) {
        /* try next */
      }
    }
    throw Exception(
      'AdminApi: no reachable base (is 9104 open on your tailnet/LAN?)',
    );
  }

  static Uri _u(String path) {
    if (_base.isEmpty) {
      throw StateError('AdminApi not initialized. Call AdminApi.init() first.');
    }
    return Uri.parse('$_base$path');
  }

  // ---------------- Normalization endpoints (unchanged) ----------------

  static Future<void> stageOne({
    required StockItem normalized,
    required String who,
  }) async {
    final body = {
      'id': normalized.id,
      'normalized_name': normalized.name,
      'normalized_producent': normalized.producent,
      'normalized_category': normalized.category,
      'normalized_description': normalized.category,
      'proposed_by': who,
    };
    final res = await http.post(
      _u('/sync/preview'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) {
      throw Exception(
        'stageOne(${normalized.id}) failed: ${res.statusCode} ${res.body}',
      );
    }
  }

  static Future<void> applyIds(List<String> ids, {required String who}) async {
    final body = {'ids': ids, 'approved_by': who};
    final res = await http.post(
      _u('/sync/apply'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) {
      throw Exception('applyIds failed: ${res.statusCode} ${res.body}');
    }
  }

  static Future<List<String>> pendingIds() async {
    final res = await http.get(_u('/sync/pending'));
    if (res.statusCode != 200) {
      throw Exception('pending failed: ${res.statusCode}');
    }
    final list = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    return list.map((m) => '${m['id_artykulu']}').toList();
  }

  // ---------------- EAN edit ----------------

  /// Calls admin PUT /products/<productId>/ean and returns a structured result.
  /// On duplicate, we also try to resolve the **conflicting product name** so
  /// the UI can show "Ten EAN już istnieje: <name>".
  static Future<SetEanResult> setEanWithResult({
    required String productId,
    required String ean,
  }) async {
    final res = await http.put(
      _u('/products/$productId/ean'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'ean': ean}),
    );

    if (res.statusCode == 200) {
      return const SetEanResult(ok: true);
    }

    Map<String, dynamic> m = {};
    try {
      m = (jsonDecode(res.body) as Map).cast<String, dynamic>();
    } catch (_) {
      return SetEanResult(ok: false, error: 'http-${res.statusCode}');
    }

    final error = m['error']?.toString();
    final conflictId = m['conflictId']?.toString();
    final current = m['current']?.toString();

    // If it's a duplicate, attempt to fetch the nice product name
    if (error == 'duplicate-ean') {
      String? conflictName;
      if (conflictId != null && conflictId.isNotEmpty) {
        try {
          final p = await ApiService.fetchProduct(conflictId);
          if (p != null) {
            conflictName = [
              p.name,
              if (p.producent.isNotEmpty) p.producent,
            ].where((s) => s.trim().isNotEmpty).join(', ');
          }
        } catch (_) {
          /* best-effort only */
        }
      }
      return SetEanResult(
        ok: false,
        error: error,
        conflictId: conflictId,
        conflictName: conflictName,
        duplicate: true,
      );
    }

    return SetEanResult(
      ok: false,
      error: error,
      current: current,
      conflictId: conflictId,
    );
  }

  /// Convenience wrapper that throws a user-friendly exception string so old
  /// call sites can keep using try/catch without refactoring.
  static Future<void> setProductEan({
    required String id,
    required String ean,
  }) async {
    final r = await setEanWithResult(productId: id, ean: ean);
    if (r.ok) return;

    if (r.duplicate) {
      final target = (r.conflictName?.trim().isNotEmpty == true)
          ? r.conflictName!
          : (r.conflictId != null ? '#${r.conflictId}' : 'inny produkt');
      throw Exception('EAN przypisany do innego produktu: $target.');
    } else if (r.error == 'already-set' || r.error == 'already-set-race') {
      final curr = (r.current ?? '').isNotEmpty ? ': ${r.current}' : '';
      throw Exception('Produkt ma już EAN$curr.');
    } else if (r.error == 'bad-ean') {
      throw Exception('Nieprawidłowy EAN (dozwolone EAN-8 lub EAN-13).');
    } else if (r.error == 'missing-ean') {
      throw Exception('Brak EAN.');
    } else {
      throw Exception('Nie udało się zapisać EAN. (${r.error ?? "błąd"})');
    }
  }
}
