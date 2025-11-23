// lib/services/admin_api.dart
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:strefa_ciszy/models/stock_item.dart';
import 'package:strefa_ciszy/services/api_service.dart';

class SetEanResult {
  final bool ok;
  final String? error;
  final String? conflictId;
  final String? conflictName;
  final String? current;
  final bool duplicate;
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
  static const String _primary = 'https://wapro-api.tail52a6fb.ts.net/api';

  static const List<String> _fallbacks = [
    'http://192.168.1.103:9103/api', // Waitress
    'http://192.168.1.151:9103/api', // LAN IP
    'http://10.0.2.2:9103/api', // Android
    // 'http://wapro-api:9103/api',
  ];

  static String _base = '';
  static String get base => _base;

  static Future<void> init() async {
    if (_base.isNotEmpty) return;

    final candidates = <String>[_primary, ..._fallbacks];

    for (final b in candidates) {
      try {
        final r = await http
            .get(Uri.parse('$b/health'))
            .timeout(const Duration(milliseconds: 1000));
        if (r.statusCode == 200) {
          _base = b;
          debugPrint('[AdminApi] BASE = $_base');
          return;
        }
      } catch (_) {
        /* try next */
      }
    }
    _base = _primary;
    debugPrint('[AdminApi] BASE (fallback) = $_base');
  }

  static Uri _u(String path) {
    if (_base.isEmpty) {
      // lazy-init safeguard
      // ignore: unawaited_futures
      init();
      return Uri.parse('$_primary$path');
    }
    return Uri.parse('$_base$path');
  }

  // ---------- Normalisation
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
      _u('/admin/sync/preview'),
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
      _u('/admin/sync/apply'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) {
      throw Exception('applyIds failed: ${res.statusCode} ${res.body}');
    }
  }

  static Future<List<String>> pendingIds() async {
    final res = await http.get(_u('/admin/sync/pending'));
    if (res.statusCode != 200) {
      throw Exception('pending failed: ${res.statusCode}');
    }
    final list = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    return list.map((m) => '${m['id_artykulu']}').toList();
  }

  // ---------- EAN ----------
  static Future<SetEanResult> setEanWithResult({
    required String productId,
    required String ean,
  }) async {
    final res = await http.put(
      _u('/admin/products/$productId/ean'),
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
        } catch (_) {}
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

  // ---------- Reservations ----------
  static Future<Map<String, dynamic>> reserveUpsert({
    required String projectId,
    String? customerId,
    required String itemId,
    required num qty,
    String? warehouseId,
    required String actorEmail,
  }) async {
    final res = await http.post(
      _u('/admin/reservations/upsert'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'projectId': projectId,
        'customerId': customerId,
        'itemId': itemId,
        'qty': qty,
        'warehouseId': warehouseId,
        'actorEmail': actorEmail,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('reserveUpsert failed: ${res.statusCode} ${res.body}');
    }
    return (jsonDecode(res.body) as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> reservationSummary({
    required String itemId,
    String? projectId,
  }) async {
    final uri = _u('/admin/reservations/summary').replace(
      queryParameters: {
        'itemId': itemId,
        if (projectId != null && projectId.isNotEmpty) 'projectId': projectId,
      },
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception(
        'reservationSummary failed: ${res.statusCode} ${res.body}',
      );
    }
    return (jsonDecode(res.body) as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> resetItemReservations({
    required String itemId,
    String? projectId,
  }) async {
    final body = {
      "itemId": itemId,
      if (projectId != null && projectId.isNotEmpty) "projectId": projectId,
    };
    return await ApiService.postJson("/admin/reservations/reset_item", body);
  }

  // ---------- Catalog (name search) ----------
  static Future<List<Map<String, dynamic>>> catalog({
    String q = '',
    int top = 100,
  }) async {
    await init();
    final uri1 = _u(
      '/catalog',
    ).replace(queryParameters: {'q': q, 'top': '$top'});

    try {
      final r1 = await http.get(uri1);
      if (r1.statusCode == 200) {
        return (jsonDecode(r1.body) as List).cast<Map<String, dynamic>>();
      }

      if (r1.statusCode >= 500) {
        return await _catalogFallbackProducts(q: q, top: top);
      }

      throw Exception('GET $uri1 failed: ${r1.statusCode} ${r1.body}');
    } catch (e) {
      try {
        return await _catalogFallbackProducts(q: q, top: top);
      } catch (_) {
        rethrow;
      }
    }
  }

  static Future<List<Map<String, dynamic>>> _catalogFallbackProducts({
    required String q,
    required int top,
  }) async {
    final uri2 = _u(
      '/products',
    ).replace(queryParameters: {'q': q, 'limit': '$top'});
    final r2 = await http.get(uri2);
    if (r2.statusCode != 200) {
      throw Exception('GET $uri2 failed: ${r2.statusCode} ${r2.body}');
    }
    final list = (jsonDecode(r2.body) as List).cast<Map<String, dynamic>>();

    return list.map((m) {
      return {
        'id_artykulu': m['id']?.toString() ?? '',
        'nazwa': (m['name'] ?? '').toString(),
        'PRODUCENT': (m['producent'] ?? '').toString(),
        'sku': (m['sku'] ?? '').toString(),
        'quantity': m['quantity'],
        'unit': m['unit'],
      };
    }).toList();
  }

  static Future<String> reserve({
    required String projectId,
    required int idArtykulu,
    required num qty,
    String user = 'app',
    String? comment,
  }) async {
    final res = await http.post(
      _u('/reserve'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'projectId': projectId,
        'idArtykulu': idArtykulu,
        'qty': qty,
        'user': user,
        'comment': comment,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('reserve failed: ${res.statusCode} ${res.body}');
    }
    final m = (jsonDecode(res.body) as Map).cast<String, dynamic>();
    return (m['reservationId'] as String?) ?? '';
  }

  static Future<void> confirm({
    required String reservationId,
    bool lockAll = true,
  }) async {
    final res = await http.post(
      _u('/confirm'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'reservationId': reservationId, 'lockAll': lockAll}),
    );
    if (res.statusCode != 200) {
      throw Exception('confirm failed: ${res.statusCode} ${res.body}');
    }
  }

  static Future<void> invoiced({
    required String reservationId,
    required String invoiceNo,
  }) async {
    final res = await http.post(
      _u('/invoiced'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'reservationId': reservationId,
        'invoiceNo': invoiceNo,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('invoiced failed: ${res.statusCode} ${res.body}');
    }
  }

  static Future<void> release({required String reservationId}) async {
    final res = await http.post(
      _u('/release'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'reservationId': reservationId}),
    );
    if (res.statusCode != 200) {
      throw Exception('release failed: ${res.statusCode} ${res.body}');
    }
  }

  static Future<String> invoicedPartial({
    required String projectId,
    required List<Map<String, dynamic>> lines,
    String? invoiceNo,
  }) async {
    await init();
    final res = await http.post(
      _u('/invoiced_partial'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'projectId': projectId,
        'invoiceNo': invoiceNo ?? '',
        'lines': lines,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('invoiced_partial failed: ${res.statusCode} ${res.body}');
    }
    final m = (jsonDecode(res.body) as Map).cast<String, dynamic>();
    if (m['ok'] != true) {
      throw Exception('invoiced_partial error: ${res.body}');
    }
    return (m['invoiceTag'] as String?) ?? (invoiceNo ?? '');
  }
}
