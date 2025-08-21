// lib/services/admin_api.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:strefa_ciszy/models/stock_item.dart';

class AdminApi {
  static const List<String> _primaryCandidates = [
    // 9104 - Tailscale HTTPS
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
}
