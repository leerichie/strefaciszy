import 'dart:convert';

import 'package:dio/dio.dart';

import '../local_repository.dart';
import '../models/product_local.dart';

/// Pulls minimal product fields from the server and stores them in Isar.

class ProductCacheRepository {
  final Dio dio;
  final String baseUrl;
  final String? apiKey;
  final LocalRepository local;

  ProductCacheRepository({
    required this.dio,
    required this.baseUrl,
    required this.local,
    this.apiKey,
  });

  Map<String, String> get _headers =>
      apiKey == null ? const {} : {'X-API-KEY': apiKey!};

  Future<int> initialSeed({int pageSize = 500, int maxPages = 200}) async {
    int total = 0;
    for (int page = 1; page <= maxPages; page++) {
      final url =
          '$baseUrl/products?page=$page&limit=$pageSize&fields='
          'id,reference,ean13,name,brand,price,quantity,updated_at';
      final res = await dio.get(url, options: Options(headers: _headers));
      if (res.statusCode != 200) break;

      final items = _extractList(res.data);
      if (items.isEmpty) break;

      await local.upsertProductLocals(items.map(_mapToLocal).toList());
      total += items.length;

      if (items.length < pageSize) break;
    }
    return total;
  }

  Future<int> refreshDeltas({DateTime? since, int pageSize = 500}) async {
    final sinceIso = (since ?? DateTime.fromMillisecondsSinceEpoch(0))
        .toUtc()
        .toIso8601String();

    int total = 0;
    for (int page = 1; page < 9999; page++) {
      final url =
          '$baseUrl/products/changed-since?since=$sinceIso&page=$page&limit=$pageSize&fields='
          'id,reference,ean13,name,brand,price,quantity,updated_at';
      final res = await dio.get(url, options: Options(headers: _headers));
      if (res.statusCode != 200) break;

      final items = _extractList(res.data);
      if (items.isEmpty) break;

      await local.upsertProductLocals(items.map(_mapToLocal).toList());
      total += items.length;

      if (items.length < pageSize) break;
    }
    return total;
  }

  // ---- helpers ----

  List _extractList(dynamic data) {
    if (data == null) return const [];
    if (data is List) return data;
    if (data is Map && data['data'] is List) return data['data'] as List;
    if (data is String) {
      try {
        final d = jsonDecode(data);
        if (d is List) return d;
        if (d is Map && d['data'] is List) return d['data'] as List;
      } catch (_) {}
    }
    return const [];
  }

  ProductLocal _mapToLocal(dynamic m) {
    final map = (m as Map);
    final p = ProductLocal()
      ..productId = '${map['id']}'
      ..reference = _asStr(map['reference'])
      ..ean13 = _asStr(map['ean13'])
      ..name = _asStr(map['name']) ?? ''
      ..brand = _asStr(map['brand'])
      ..price = _asDouble(map['price'])
      ..qtyCached = _asDouble(map['quantity'])
      ..updatedAt = _asDate(map['updated_at']);
    p.normalize();
    return p;
  }

  String? _asStr(dynamic v) => v?.toString();
  double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  DateTime? _asDate(dynamic v) {
    if (v == null) return null;
    try {
      return DateTime.parse(v.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }
}
