import 'package:dio/dio.dart';
import 'package:strefa_ciszy/services/admin_api.dart';

import 'local_repository.dart';
import 'product_cache_sync.dart';
import 'repositories/product_cache_repository.dart';

Future<void> warmProductCache() async {
  await AdminApi.init();

  final local = await LocalRepository.create();
  final repo = ProductCacheRepository(
    dio: Dio(),
    baseUrl: AdminApi.base,
    local: local,
  );

  final sync = await ProductCacheSync.create(repo: repo);
  await sync.warm();
}
