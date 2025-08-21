// lib/models/stock_item.dart
class StockItem {
  final String id;
  final String name;
  final String description;
  final int quantity;
  final String sku;
  final String barcode;
  final String unit;
  final String producent;
  final String? imageUrl;
  final String category; // API sets = description

  StockItem({
    required this.id,
    required this.name,
    required this.description,
    required this.quantity,
    required this.sku,
    required this.barcode,
    required this.unit,
    required this.producent,
    required this.imageUrl,
    required this.category,
  });

  StockItem copyWith({
    String? id,
    String? name,
    String? description,
    int? quantity,
    String? sku,
    String? barcode,
    String? unit,
    String? producent,
    String? imageUrl,
    String? category,
  }) {
    return StockItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      unit: unit ?? this.unit,
      producent: producent ?? this.producent,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
    );
  }

  // ---- API JSON helpers ----
  factory StockItem.fromJson(Map<String, dynamic> j) {
    String s(dynamic v) => (v == null) ? "" : v.toString();
    int i(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    // Safe category fallback: prefer category; if empty use description.
    final cat = (j['category'] ?? '').toString().trim();
    final desc = (j['description'] ?? '').toString().trim();

    return StockItem(
      id: s(j['id']),
      name: s(j['name']),
      description: desc,
      quantity: i(j['quantity']),
      sku: s(j['sku']),
      barcode: s(j['barcode']),
      unit: s(j['unit']),
      producent: s(j['producent']),
      imageUrl: (j['imageUrl'] == null || j['imageUrl'].toString().isEmpty)
          ? null
          : j['imageUrl'].toString(),
      category: cat.isNotEmpty ? cat : desc,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'quantity': quantity,
    'sku': sku,
    'barcode': barcode,
    'unit': unit,
    'producent': producent,
    'imageUrl': imageUrl,
    'category': category,
  };

  // ---- Firestore shims (so withConverter compiles) ----
  // Your old Firestore docs typically had the same keys.
  // We keep the same normalization (null -> '' / 0).
  factory StockItem.fromMap(Map<String, dynamic> m, String id) {
    String s(dynamic v) => (v == null) ? "" : v.toString();
    int i(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    final desc = s(m['description']);
    final catRaw = s(m['category']).trim();
    final cat = catRaw.isNotEmpty ? catRaw : desc;

    return StockItem(
      id: id,
      name: s(m['name']),
      description: desc,
      quantity: i(m['quantity']),
      sku: s(m['sku']),
      barcode: s(m['barcode']),
      unit: s(m['unit']),
      producent: s(m['producent']),
      imageUrl: (m['imageUrl'] == null || m['imageUrl'].toString().isEmpty)
          ? null
          : m['imageUrl'].toString(),
      category: cat,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'description': description,
    'quantity': quantity,
    'sku': sku,
    'barcode': barcode,
    'unit': unit,
    'producent': producent,
    'imageUrl': imageUrl,
    'category': category,
  };
}
