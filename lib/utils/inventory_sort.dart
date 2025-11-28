// lib/utils/inventory_sort.dart
import 'package:strefa_ciszy/models/stock_item.dart';

enum InventorySortField {
  quantity,
  producer,
  unit,
  category,
  // name,
}

String inventorySortFieldLabel(InventorySortField field) {
  switch (field) {
    case InventorySortField.quantity:
      return 'Stan';
    case InventorySortField.producer:
      return 'Producent';
    case InventorySortField.unit:
      return 'Jednostka';
    case InventorySortField.category:
      return 'Kategoria';
    // case InventorySortField.name:
    //   return 'Nazwa';
  }
}

List<StockItem> applyInventorySort(
  List<StockItem> items, {
  required InventorySortField field,
  required bool ascending,
}) {
  var sorted = List<StockItem>.from(items);

  int cmpNum(num? a, num? b) {
    final aa = a ?? 0;
    final bb = b ?? 0;
    return aa.compareTo(bb);
  }

  int cmpStr(String? a, String? b) {
    final aa = (a ?? '').toLowerCase().trim();
    final bb = (b ?? '').toLowerCase().trim();
    return aa.compareTo(bb);
  }

  switch (field) {
    case InventorySortField.quantity:
      sorted.sort((a, b) => cmpNum(a.quantity, b.quantity));
      break;

    case InventorySortField.producer:
      sorted.sort((a, b) => cmpStr(a.producent, b.producent));
      break;

    case InventorySortField.unit:
      sorted.sort((a, b) => cmpStr(a.unit, b.unit));
      break;

    case InventorySortField.category:
      sorted.sort((a, b) => cmpStr(a.category, b.category));
      break;

    // case InventorySortField.name:
    //   sorted.sort((a, b) => _cmpStr(a.name, b.name));
    //   break;
  }

  if (!ascending) {
    sorted = sorted.reversed.toList();
  }

  return sorted;
}
