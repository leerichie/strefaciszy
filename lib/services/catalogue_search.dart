import 'package:strefa_ciszy/services/admin_api.dart';

import 'catalogue_search_platform_io.dart'
    if (dart.library.html) 'catalogue_search_platform_web.dart'
    as platform;

Future<List<Map<String, dynamic>>> catalogSearchHybrid(
  String q, {
  int top = 100,
  bool includeOnline = true,
}) async {
  final localMapped = await platform.localSearch(q, top);
  if (!includeOnline) return localMapped.take(top).toList();

  List<Map<String, dynamic>> online = const [];
  try {
    await AdminApi.init();
    online = await AdminApi.catalog(q: q, top: top);
  } catch (_) {}

  final byId = <String, Map<String, dynamic>>{};
  for (final m in localMapped) {
    final id = (m['id_artykulu'] ?? '').toString();
    if (id.isNotEmpty) byId[id] = m;
  }
  for (final m in online) {
    final id = (m['id_artykulu'] ?? '').toString();
    if (id.isNotEmpty) byId[id] = m;
  }
  return byId.values.take(top).toList();
}
