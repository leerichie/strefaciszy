// lib/services/stock_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:strefa_ciszy/models/stock_item.dart';
import '../models/project_line.dart';

class StockService {
  StockService._();

  static Future<void> applyProjectLinesTransaction({
    required String customerId,
    required String projectId,
    required String rwDocId,
    required Map<String, dynamic> rwDocData,
    required bool isNew,
    required List<ProjectLine> lines,
    required String newStatus,
    required String userId,
  }) {
    final db = FirebaseFirestore.instance;

    final projectRef = db
        .collection('customers')
        .doc(customerId)
        .collection('projects')
        .doc(projectId);
    final rwRef = projectRef.collection('rw_documents').doc(rwDocId);

    debugPrint('🏷️ Starting transaction for RW doc $rwDocId (isNew=$isNew)');
    debugPrint('   Total lines passed in: ${lines.length}');

    return db.runTransaction((tx) async {
      for (final ln in lines.where((l) => l.isStock)) {
        await _applyLineDelta(tx, ln, userId);
      }

      if (isNew) {
        tx.set(rwRef, rwDocData);
      } else {
        tx.update(rwRef, {
          'items': rwDocData['items'],
          'type': rwDocData['type'],
          'lastUpdatedAt': FieldValue.serverTimestamp(),
          'lastUpdatedBy': userId,
        });
      }

      final updatedLines = lines
          .where((l) => l.isStock && l.requestedQty > 0)
          .toList();

      tx.update(projectRef, {
        'items': updatedLines.map((l) => l.toMap()).toList(),
        'status': newStatus,
        'lastRwDate': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<void> _applyLineDelta(
    Transaction tx,
    ProjectLine ln,
    String userId,
  ) async {
    final stockRef = FirebaseFirestore.instance
        .collection('stock_items')
        .doc(ln.itemRef);
    final snap = await tx.get(stockRef);
    final data = snap.data();
    if (data == null) {
      throw Exception('Produkt ${ln.itemRef} nie istnieje');
    }

    final currentQty = (data['quantity'] as int? ?? 0);
    final delta = ln.requestedQty - ln.previousQty;

    if (delta > 0) {
      if (delta > currentQty) {
        throw Exception('Za mało ${data['name']} (brakuje $delta)');
      }
      tx.update(stockRef, {
        'quantity': currentQty - delta,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': userId,
      });
    } else if (delta < 0) {
      tx.update(stockRef, {
        'quantity': currentQty + (-delta),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': userId,
      });
    }

    ln.previousQty = ln.requestedQty;
  }

  static Map<String, dynamic> buildRwDocMap(
    String id,
    String projectId,
    String projectName,
    String createdBy,
    DateTime createdAt,
    String type,
    List<ProjectLine> lines,
    List<StockItem> allStockItems,
    String customerId,
  ) {
    final createdDay = DateTime.utc(
      createdAt.year,
      createdAt.month,
      createdAt.day,
    );
    return {
      'id': id,
      'projectId': projectId,
      'projectName': projectName,
      'customerId': customerId,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'createdDay': Timestamp.fromDate(createdDay),
      'type': type,
      'items': lines.map((l) {
        final name = l.isStock
            ? allStockItems.firstWhere((s) => s.id == l.itemRef).name
            : l.customName;
        return {
          'itemId': l.itemRef,
          'name': name,
          'quantity': l.requestedQty,
          'unit': l.unit,
        };
      }).toList(),
    };
  }
}
