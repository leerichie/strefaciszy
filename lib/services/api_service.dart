// lib/services/api_service.dart
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
// import 'package:strefa_ciszy/utils/stock_normalizer.dart';
import '../models/stock_item.dart';

class PagedItems {
  final List<StockItem> items;
  final int offset;
  final int nextOffset;
  final bool hasMore;
  const PagedItems({
    required this.items,
    required this.offset,
    required this.nextOffset,
    required this.hasMore,
  });
}

class ApiService {
  /// HTTPS
  static const String _primary = "https://wapro-api.tail52a6fb.ts.net/api";

  /// Native fallbacks
  static const List<String> _nativeFallbacks = [
    // MagicDNS tailnet (Android/iOS/macOS/Windows apps)
    "http://wapro-api:9103/api",
    //  Tailscale
    "http://100.86.227.1:9103/api",
    //  LAN box
    "http://192.168.1.103:9103/api",
    // Android emulator
    "http://10.0.2.2:9103/api",
  ];

  static String _base = _primary;

  static Future<void> init() async {
    final candidates = kIsWeb
        ? <String>[_primary]
        : <String>[_primary, ..._nativeFallbacks];

    for (final b in candidates) {
      try {
        final r = await http
            .get(Uri.parse("$b/health"))
            .timeout(const Duration(seconds: 3));
        if (r.statusCode == 200) {
          _base = b;
          break;
        }
      } catch (_) {
        /* try next */
      }
    }
    debugPrint('[ApiService] BASE = $_base');
  }

  static Uri _uri(String path, [Map<String, dynamic>? q]) {
    final u = Uri.parse("$_base$path");
    if (q == null || q.isEmpty) return u;
    final qp = <String, String>{};
    q.forEach((k, v) {
      if (v == null) return;
      final s = v.toString();
      if (s.isEmpty) return;
      qp[k] = s;
    });
    return u.replace(queryParameters: qp);
  }

  static Future<List<StockItem>> fetchProducts({
    String? search,
    String? category,
    int limit = 50,
    int offset = 0,
  }) async {
    final uri = _uri('/products', {
      'name': search,
      'q': search,
      'category': category,
      'limit': limit,
      'offset': offset,
    });

    final res = await http.get(
      uri,
      headers: {'Accept': 'application/json', 'Cache-Control': 'no-cache'},
    );
    debugPrint('[ApiService] GET $uri -> ${res.statusCode}');

    if (res.statusCode != 200) {
      throw Exception('GET $uri failed: ${res.statusCode}');
    }

    final body = json.decode(res.body);
    if (body is! List) {
      throw Exception('Unexpected response for /products: not a list');
    }

    final items = body
        .map<StockItem>((e) => StockItem.fromJson(e as Map<String, dynamic>))
        .toList();

    if (items.isEmpty) {
      debugPrint('[ApiService] Empty list from API');
    } else {
      debugPrint(
        '[ApiService] First item: id=${items.first.id} name=${items.first.name}',
      );
    }
    return items;
  }

  static Future<PagedItems> fetchProductsPaged({
    String? search,
    String? category,
    int limit = 50,
    int offset = 0,
  }) async {
    final items = await fetchProducts(
      search: search,
      category: category,
      limit: limit,
      offset: offset,
    );
    final hasMore = items.length >= limit;
    return PagedItems(
      items: items,
      offset: offset,
      nextOffset: offset + items.length,
      hasMore: hasMore,
    );
  }

  static Future<StockItem?> fetchProduct(String id) async {
    final uri = _uri('/products/$id');
    final res = await http.get(uri);

    if (res.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(res.body);
      final item = StockItem.fromJson(data);
      // return StockNormalizer.normalize(item);
      return item;
    } else if (res.statusCode == 404) {
      return null;
    } else {
      throw Exception('GET ${uri.path} failed: ${res.statusCode} ${res.body}');
    }
  }

  static Future<List<String>> fetchCategories() async {
    final uri = _uri('/categories');
    final res = await http.get(uri);
    debugPrint('[ApiService] GET $uri -> ${res.statusCode}');

    if (res.statusCode != 200) {
      throw Exception('GET ${uri.path} failed: ${res.statusCode} ${res.body}');
    }

    final body = json.decode(res.body);
    if (body is! List) {
      throw Exception('Unexpected response for /categories');
    }

    return body
        .map((e) => (e?.toString() ?? '').trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// approval -> final commit into WAPRO
  static Future<Map<String, dynamic>> commitProjectItems({
    required String customerId,
    required String projectId,
    required List<Map<String, dynamic>> items,
    required String actorEmail,
    bool dryRun = false,
  }) async {
    final uri = _uri('/commit');

    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();

    final payload = {
      'customerId': customerId,
      'projectId': projectId,
      'items': items,
      'actorEmail': actorEmail,
      'dryRun': dryRun,
    };

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (idToken != null) 'Authorization': 'Bearer $idToken',
      'X-Actor-Email': actorEmail,
    };

    final res = await http.post(
      uri,
      headers: headers,
      body: json.encode(payload),
    );

    debugPrint('[ApiService] POST $uri -> ${res.statusCode}');

    if (res.statusCode != 200) {
      throw Exception('POST $uri failed: ${res.statusCode} ${res.body}');
    }

    final body = json.decode(res.body);
    if (body is Map<String, dynamic>) return body;

    throw Exception('Unexpected /commit response format');
  }

  /// Accountant-only: commit selected project items to WAPRO (official deduction).
  /// Backend endpoint expected: POST /commit
  /// Body:
  /// {
  ///   "customerId": "...",
  ///   "projectId":  "...",
  ///   "items": [ { "itemId":"...", "qty": 3, "unit":"szt", "name":"...", "producer":"..." }, ... ],
  ///   "dryRun": false,
  ///   "actorEmail": "accountant@company.com"
  /// }
  /// Returns JSON (e.g. { ok:true, docId:"WZ-00123", ... }).
}
