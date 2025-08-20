// lib/models/stock_item.dart
class StockItem {
  final String id; // stringified id
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
    String _s(dynamic v) => (v == null) ? "" : v.toString();
    int _i(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    // Safe category fallback: prefer category; if empty use description.
    final _cat = (j['category'] ?? '').toString().trim();
    final _desc = (j['description'] ?? '').toString().trim();

    return StockItem(
      id: _s(j['id']),
      name: _s(j['name']),
      description: _desc,
      quantity: _i(j['quantity']),
      sku: _s(j['sku']),
      barcode: _s(j['barcode']),
      unit: _s(j['unit']),
      producent: _s(j['producent']),
      imageUrl: (j['imageUrl'] == null || j['imageUrl'].toString().isEmpty)
          ? null
          : j['imageUrl'].toString(),
      category: _cat.isNotEmpty ? _cat : _desc,
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
    String _s(dynamic v) => (v == null) ? "" : v.toString();
    int _i(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    final desc = _s(m['description']);
    final catRaw = _s(m['category']).trim();
    final cat = catRaw.isNotEmpty ? catRaw : desc;

    return StockItem(
      id: id,
      name: _s(m['name']),
      description: desc,
      quantity: _i(m['quantity']),
      sku: _s(m['sku']),
      barcode: _s(m['barcode']),
      unit: _s(m['unit']),
      producent: _s(m['producent']),
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
