// lib/services/stock_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/project_line.dart'; // adjust path if needed

class StockService {
  StockService._(); // private ctor—static methods only

  /// Apply all the deltas in `lines` to stock inside a single transaction,
  /// then write an RW doc and update the project items+status.
  ///
  /// Throws a [FirebaseException] if any update is denied, or an [Exception]
  /// if you try to deduct more than is available.
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
      // 1) adjust stock items
      for (final ln in lines.where((l) => l.isStock)) {
        await _applyLineDelta(tx, ln, userId);
      }

      // 2) write RW doc
      tx.set(rwRef, rwDocData);

      // 3) update project doc
      tx.update(projectRef, {
        'items': lines.map((l) => l.toMap()).toList(),
        'status': newStatus,
      });
    });
  }

  /// Compute delta = requestedQty - previousQty, and either
  /// subtract (delta>0) or add back (delta<0) to stock.
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

    final currentQty = (data['quantity'] ?? 0) as int;
    final delta = ln.requestedQty - ln.previousQty;

    if (delta > 0) {
      // need to subtract extra
      if (delta > currentQty) {
        throw Exception('Za mało ${data['name']} (brakuje $delta)');
      }
      tx.update(stockRef, {
        'quantity': currentQty - delta,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': userId,
      });
    } else if (delta < 0) {
      // return the excess
      tx.update(stockRef, {
        'quantity': currentQty + (-delta),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': userId,
      });
    }
    // keep in-memory in sync
    ln.previousQty = ln.requestedQty;
  }

  /// Convenience to build the RW-document payload from your RWDocument model.
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
