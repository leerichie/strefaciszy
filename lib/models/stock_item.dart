// lib/models/stock_item.dart

class StockItem {
  final String id;
  final String name;
  final String description;
  final int quantity;
  final String? sku;
  final String? barcode;
  final String? unit;
  final String? producent;
  final String? imageUrl;

  StockItem({
    required this.id,
    required this.name,
    required this.description,
    required this.quantity,
    this.sku,
    this.barcode,
    this.unit,
    this.producent,
    this.imageUrl,
  });

  factory StockItem.fromMap(Map<String, dynamic> map, String docId) {
    return StockItem(
      id: docId,
      name: map['name'] ?? '',
      description: map['category'] as String? ?? '',
      quantity: map['quantity'] ?? 0,
      sku: map['sku'],
      barcode: map['barcode'],
      unit: map['unit'],
      producent: map['producent'],
      imageUrl: map['imageUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'quantity': quantity,
      'sku': sku,
      'barcode': barcode,
      if (unit != null) 'unit': unit,
      if (producent != null) 'producent': producent,
      if (imageUrl != null) 'imageUrl': imageUrl,
    };
  }
}
