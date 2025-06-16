class StockItem {
  final String id;
  final String name;
  final int quantity;
  final String? unit;
  final String? description;

  StockItem({
    required this.id,
    required this.name,
    required this.quantity,
    this.unit,
    this.description,
  });

  factory StockItem.fromMap(Map<String, dynamic> map, String docId) {
    return StockItem(
      id: docId,
      name: map['name'] ?? '',
      quantity: map['quantity'] ?? 0,
      unit: map['unit'],
      description: map['description'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      if (unit != null) 'unit': unit,
      if (description != null) 'description': description,
    };
  }
}
