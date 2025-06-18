import 'package:cloud_firestore/cloud_firestore.dart';

/// A single line item in a project, either from stock or a custom entry.
class ProjectLine {
  /// Whether this item comes from stock or is a custom entry.
  final bool isStock;

  /// The Firestore document ID of the stock item. Empty for custom items.
  final String itemRef;

  /// The custom name, used only when isStock == false.
  final String customName;

  /// Quantity requested for the project.
  int requestedQty;

  /// Unit of measure (e.g. "szt", "kg").
  final String unit;

  /// Stock quantity at time of adding/editing (for rollback calculations).
  final int originalStock;

  /// The quantity previously reserved/used (to calculate deltas on update).
  int previousQty;

  ProjectLine({
    required this.isStock,
    required this.itemRef,
    this.customName = '',
    required this.requestedQty,
    this.unit = 'szt',
    required this.originalStock,
    required this.previousQty,
  });

  /// Create a ProjectLine from Firestore data payload.
  factory ProjectLine.fromMap(Map<String, dynamic> map) {
    final hasRef = map.containsKey('itemRef');
    final qty = map['requestedQty'] as int? ?? 0;
    return ProjectLine(
      isStock: hasRef,
      itemRef: map['itemRef'] as String? ?? '',
      customName: map['customName'] as String? ?? '',
      requestedQty: qty,
      unit: map['unit'] as String? ?? 'szt',
      originalStock: map['originalStock'] as int? ?? qty,
      previousQty: map['previousQty'] as int? ?? qty,
    );
  }

  /// Serialize to Firestore-friendly map.
  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{
      'requestedQty': requestedQty,
      'unit': unit,
      'originalStock': originalStock,
      'previousQty': previousQty,
    };
    if (isStock) {
      m['itemRef'] = itemRef;
    } else {
      m['customName'] = customName;
    }
    return m;
  }
}
