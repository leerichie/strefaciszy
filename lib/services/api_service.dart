// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:strefa_ciszy/utils/stock_normalizer.dart';
import '../models/stock_item.dart';

/// Simple paging wrapper that you can use for "load more" lists.
/// If you don't need paging yet, just ignore and keep using fetchProducts().
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
  // ✅ Your Tailscale base URL (left exactly as you provided)
  static const String baseUrl = "http://100.93.209.78:9103/api";

  // ---- helpers ----
  static Uri _uri(String path, [Map<String, dynamic>? q]) {
    final u = Uri.parse('$baseUrl$path');
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
    // -------- TEMP: flip to true to force-test your LAN IP instead of Tailscale
    const bool _forceLan = false;

    final uri = _forceLan
        ? Uri.parse('http://192.168.1.103:9103/api/products').replace(
            queryParameters: {
              'name': search ?? '',
              'q': search ?? '',
              'category': category ?? '',
              'limit': '$limit',
              'offset': '$offset',
            },
          )
        : _uri('/products', {
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

    // ==== DEBUG LOGS (show up in the browser console on Flutter Web) ====
    // ignore: avoid_print
    print('[ApiService] GET $uri -> ${res.statusCode}');
    if (res.statusCode != 200) {
      // ignore: avoid_print
      print('[ApiService] Body: ${res.body}');
      throw Exception('GET $uri failed: ${res.statusCode}');
    }

    final body = json.decode(res.body);
    if (body is! List) {
      // ignore: avoid_print
      print('[ApiService] Unexpected body type: ${body.runtimeType}');
      throw Exception('Unexpected response for /products: not a list');
    }

    final items = body
        .map<StockItem>((e) => StockItem.fromJson(e as Map<String, dynamic>))
        .map(StockNormalizer.normalize)
        .toList();

    if (items.isNotEmpty) {
      // ignore: avoid_print
      print(
        '[ApiService] First item: id=${items.first.id} name=${items.first.name}',
      );
    } else {
      // ignore: avoid_print
      print('[ApiService] Empty list from API');
    }

    return items;
  }

  // Optional: call this if you want paging signals (hasMore/nextOffset).
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
    final hasMore = items.length >= limit; // infer from count
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
      return StockNormalizer.normalize(item); // <<<<<<<<
    } else if (res.statusCode == 404) {
      return null;
    } else {
      throw Exception('GET ${uri.path} failed: ${res.statusCode} ${res.body}');
    }
  }

  // ---- CATEGORIES ----
  static Future<List<String>> fetchCategories() async {
    final uri = _uri('/categories');
    final res = await http.get(uri);
    assert(() {
      // ignore: avoid_print
      print('[ApiService] GET $uri -> ${res.statusCode}');
      return true;
    }());

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
}
