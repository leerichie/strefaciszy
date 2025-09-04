import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
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
  // WEB
  static const String _primaryWeb = 'https://wapro-api.tail52a6fb.ts.net/api';

  static const String _primaryNative =
      'https://wapro-api.tail52a6fb.ts.net/api';

  // Native
  static const List<String> _nativeFallbacks = [
    'http://wapro-api:9103/api',
    'http://100.86.227.1:9103/api',
    'http://192.168.1.103:9103/api',
    'http://10.0.2.2:9103/api',
  ];

  static String _base = '';

  static Future<void> init() async {
    if (_base.isNotEmpty) return;

    final candidates = kIsWeb
        ? <String>[_primaryWeb]
        : <String>[_primaryNative, ..._nativeFallbacks];

    for (final b in candidates) {
      try {
        final r = await http
            .get(Uri.parse('$b/health'))
            .timeout(const Duration(seconds: 3));
        if (r.statusCode == 200) {
          _base = b;
          return;
        }
      } catch (_) {
        /* try next */
      }
    }
    _base = candidates.first;
  }

  static Uri _u(String path) {
    if (_base.isEmpty) {
      init();
      return Uri.parse('${(_base.isEmpty ? _primaryWeb : _base)}$path');
    }
    return Uri.parse('$_base$path');
  }

  // ---------- Normalization ----------
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

  // --- Catalog with availability (joins v_AppCatalog)
  static Future<List<Map<String, dynamic>>> catalog({
    String q = '',
    int top = 100,
  }) async {
    final uri = _u(
      '/catalog',
    ).replace(queryParameters: {'q': q, 'top': '$top'});
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('GET $uri failed: ${res.statusCode} ${res.body}');
    }
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
  }

  // --- New reservation flow (stored-procs backend) ---
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
      // Proc throws when overbooking is attempted — surface message
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
}
