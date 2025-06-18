import 'package:cloud_firestore/cloud_firestore.dart';

class ProjectLine {
  final bool isStock;

  final String itemRef;

  final String customName;

  int requestedQty;

  final String unit;

  final int originalStock;

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

  ProjectLine copyWith({
    bool? isStock,
    String? itemRef,
    String? customName,
    int? requestedQty,
    String? unit,
    int? originalStock,
    int? previousQty,
  }) {
    return ProjectLine(
      isStock: isStock ?? this.isStock,
      itemRef: itemRef ?? this.itemRef,
      customName: customName ?? this.customName,
      requestedQty: requestedQty ?? this.requestedQty,
      unit: unit ?? this.unit,
      originalStock: originalStock ?? this.originalStock,
      previousQty: previousQty ?? this.previousQty,
    );
  }
}
