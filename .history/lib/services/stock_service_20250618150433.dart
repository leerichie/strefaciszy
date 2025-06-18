// lib/services/stock_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:strefa_ciszy/models/stock_item.dart';
import '../models/project_line.dart';

class StockService {
  StockService._();

  /// Atomically applies all ProjectLine deltas, creates an RW document,
  /// and updates the project’s items & status.
  static Future<void> applyProjectLinesTransaction({
    required String customerId,
    required String projectId,
    required String rwDocId,
    required Map<String, dynamic> rwDocData,
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
    final rwRef = db.collection('rw_documents').doc(rwDocId);

    return db.runTransaction((tx) async {
      // 1) Adjust stock for each stock‐type line
      for (final ln in lines.where((l) => l.isStock)) {
        await _applyLineDelta(tx, ln, userId);
      }

      // 2) Create the RW/MM document
      tx.set(rwRef, rwDocData);

      // 3) Update the project with new items list and status
      tx.update(projectRef, {
        'items': lines.map((l) => l.toMap()).toList(),
        'status': newStatus,
      });
    });
  }

  /// Applies a single ProjectLine’s delta to the corresponding stock item.
  /// - If delta > 0, subtracts that amount.
  /// - If delta < 0, returns that amount back to stock.
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
      // subtract extra
      if (delta > currentQty) {
        throw Exception('Za mało ${data['name']} (brakuje $delta)');
      }
      tx.update(stockRef, {
        'quantity': currentQty - delta,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': userId,
      });
    } else if (delta < 0) {
      // return surplus
      tx.update(stockRef, {
        'quantity': currentQty + (-delta),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': userId,
      });
    }

    // update in-memory marker so next edit computes correctly
    ln.previousQty = ln.requestedQty;
  }

  /// Constructs the map for the RW/MM document.
  static Map<String, dynamic> buildRwDocMap(
    String id,
    String projectId,
    String projectName,
    String createdBy,
    DateTime createdAt,
    String type,
    List<ProjectLine> lines,
    List<StockItem> allStockItems,
  ) {
    return {
      'id': id,
      'projectId': projectId,
      'projectName': projectName,
      'createdBy': createdBy,
      'createdAt': createdAt,
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
