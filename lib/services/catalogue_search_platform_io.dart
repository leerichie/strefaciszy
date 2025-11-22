import 'package:strefa_ciszy/offline/local_repository.dart';

Future<List<Map<String, dynamic>>> localSearch(String q, int limit) async {
  final repo = await LocalRepository.create();
  final hits = await repo.searchProductsLocal(q, limit: limit);
  return hits
      .map<Map<String, dynamic>>(
        (p) => {
          'id_artykulu': p.productId,
          'nazwa': p.name,
          'PRODUCENT': p.brand ?? '',
          'sku': p.reference ?? '',
          'barcode': p.ean13 ?? '',
          'quantity': p.qtyCached,
          'unit': null,
        },
      )
      .toList();
}
