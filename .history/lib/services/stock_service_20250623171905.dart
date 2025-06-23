// lib/services/stock_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:strefa_ciszy/models/stock_item.dart';
import '../models/project_line.dart';

class StockService {
  StockService._();

  /// Applies a set of project lines (RW/MM) inside a Firestore transaction.
  /// - For each stock line: adjusts the stock quantity by –delta.
  /// - Creates or updates the RW document with server timestamps and user IDs.
  /// - Updates the parent project’s items/status/lastRwDate.
  static Future<void> applyProjectLinesTransaction({
    required String customerId,
    required String projectId,
    required String rwDocId,
    required Map<String, dynamic> rwDocData,
    required bool isNew,
    required List<ProjectLine> lines,
    required String newStatus,
    required String userId,
  }) async {
    final db = FirebaseFirestore.instance;
    final projRef = db
        .collection('customers')
        .doc(customerId)
        .collection('projects')
        .doc(projectId);
    final rwRef = projRef.collection('rw_documents').doc(rwDocId);

    await db.runTransaction((tx) async {
      // 1) For each stock‐line, atomically increment by –delta
      for (final ln in lines.where((l) => l.isStock)) {
        final stockRef = db.collection('stock_items').doc(ln.itemRef);
        final snap = await tx.get(stockRef);
        if (!snap.exists) {
          throw Exception('Produkt ${ln.itemRef} nie istnieje');
        }
        final current = (snap.data()!['quantity'] as int?) ?? 0;
        final delta = ln.requestedQty - ln.previousQty;
        if (delta > 0 && delta > current) {
          throw Exception('Za mało towaru (${ln.itemRef})');
        }
        if (delta != 0) {
          tx.update(stockRef, {
            'quantity': FieldValue.increment(-delta),
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': userId,
          });
        }
        // keep in‐memory in sync
        ln.previousQty = ln.requestedQty;
      }

      // 2) Create or update the RW doc
      if (isNew) {
        // On creation, stamp createdAt/createdBy with server values
        final dataWithTimestamps = Map<String, dynamic>.from(rwDocData)
          ..['createdAt'] = FieldValue.serverTimestamp()
          ..['createdBy'] = userId;
        tx.set(rwRef, dataWithTimestamps);
      } else {
        // On edits, update items/type plus lastUpdatedAt/lastUpdatedBy
        tx.update(rwRef, {
          'items': rwDocData['items'],
          'type': rwDocData['type'],
          'lastUpdatedAt': FieldValue.serverTimestamp(),
          'lastUpdatedBy': userId,
        });
      }

      // 3) Write back the filtered project items and status
      final remaining = lines
          .where((l) => l.isStock && l.requestedQty > 0)
          .map((l) => l.toMap())
          .toList();
      tx.update(projRef, {
        'items': remaining,
        'status': newStatus,
        'lastRwDate': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Increases the stock quantity for an item by [qty].
  static Future<void> increaseQty(String itemId, int qty) async {
    final ref = FirebaseFirestore.instance
        .collection('stock_items')
        .doc(itemId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null) throw Exception('Produkt $itemId nie istnieje');

      final rawQty = data['quantity'];
      final currentQty = (rawQty is int)
          ? rawQty
          : (rawQty is double ? rawQty.round() : 0);

      tx.update(ref, {
        'quantity': currentQty + qty,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// (Unused in current flow) Helper to apply a single line’s delta inside
  /// a transaction, stamping update metadata.
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
    if (!data.containsKey('quantity')) {
      throw Exception('Brakuje pola quantity w produkcie ${ln.itemRef}');
    }

    final currentQty = (data['quantity'] as int? ?? 0);
    final delta = ln.requestedQty - ln.previousQty;

    debugPrint('🔄 Applying delta: $delta for ${ln.itemRef}');

    try {
      if (delta > 0) {
        if (delta > currentQty) {
          throw Exception('Za mało ${data['name']} (brakuje $delta)');
        }

        final newQty = currentQty - delta;
        debugPrint('➡️ Before stock update: ${ln.itemRef}');
        debugPrint('   currentQty=$currentQty');
        debugPrint('   delta=$delta');
        debugPrint('   newQty=$newQty');
        debugPrint('   userId=$userId');

        tx.update(stockRef, {
          'quantity': newQty,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': userId,
        });
      }
    } catch (e) {
      debugPrint('❌ Error in tx.update for ${ln.itemRef}: $e');
      rethrow;
    }

    ln.previousQty = ln.requestedQty;
  }

  /// Constructs the base RW document map. Timestamps/user fields are added
  /// in [applyProjectLinesTransaction].
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
