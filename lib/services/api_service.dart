// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
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

  // ---- PRODUCTS LIST ----
  // Backward-compatible: you can still call fetchProducts() with no args.
  // Now also supports search, category filter, and paging (limit/offset).
  static Future<List<StockItem>> fetchProducts({
    String? search, // maps to ?q=
    String? category, // maps to ?category=
    int limit = 50,
    int offset = 0,
  }) async {
    final uri = _uri('/products', {
      'q': search,
      'category': category,
      'limit': limit,
      'offset': offset,
    });

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('GET ${uri.path} failed: ${res.statusCode} ${res.body}');
    }

    final body = json.decode(res.body);
    if (body is! List) {
      throw Exception('Unexpected response for /products: not a list');
    }

    return body
        .map<StockItem>((e) => StockItem.fromJson(e as Map<String, dynamic>))
        .toList();
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

  // ---- SINGLE PRODUCT ----
  static Future<StockItem?> fetchProduct(String id) async {
    final uri = _uri('/products/$id');
    final res = await http.get(uri);

    if (res.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(res.body);
      return StockItem.fromJson(data);
    } else if (res.statusCode == 404) {
      return null; // product not found
    } else {
      throw Exception('GET ${uri.path} failed: ${res.statusCode} ${res.body}');
    }
  }

  // ---- CATEGORIES ----
  static Future<List<String>> fetchCategories() async {
    final uri = _uri('/categories');
    final res = await http.get(uri);

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
