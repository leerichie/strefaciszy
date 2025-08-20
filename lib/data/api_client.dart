import 'package:dio/dio.dart';
import '../models/stock_item.dart';

class ApiClient {
  static const String baseUrl = 'http://192.168.1.103:9103';

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 8),
    ),
  );

  Future<List<StockItem>> listProducts({
    String? q,
    int limit = 100,
    int offset = 0,
  }) async {
    final res = await _dio.get(
      '/api/products',
      queryParameters: {
        if (q != null && q.trim().isNotEmpty) 'q': q,
        'limit': limit,
        'offset': offset,
      },
    );
    final data = (res.data as List);
    return data
        .map((e) => StockItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<StockItem?> getProduct(String id) async {
    try {
      final res = await _dio.get('/api/products/$id');
      return StockItem.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}
