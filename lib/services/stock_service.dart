import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // for debugPrint
import 'package:strefa_ciszy/models/stock_item.dart';
import 'package:strefa_ciszy/utils/search_utils.dart';
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
  }) async {
    final db = FirebaseFirestore.instance;
    final projRef = db
        .collection('customers')
        .doc(customerId)
        .collection('projects')
        .doc(projectId);
    final rwRef = projRef.collection('rw_documents').doc(rwDocId);

    await db.runTransaction((tx) async {
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
        ln.previousQty = ln.requestedQty;
      }

      if (isNew) {
        final dataWithTimestamps = Map<String, dynamic>.from(rwDocData)
          ..['createdAt'] = FieldValue.serverTimestamp()
          ..['createdBy'] = userId;
        tx.set(rwRef, dataWithTimestamps);
      } else {
        tx.update(rwRef, {
          'items': rwDocData['items'],
          'type': rwDocData['type'],
          'lastUpdatedAt': FieldValue.serverTimestamp(),
          'lastUpdatedBy': userId,
        });
      }

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

  // --- search / resolve helpers ---

  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  searchStockItems(String query) async {
    final col = FirebaseFirestore.instance.collection('stock_items');
    final norm = normalize(query);

    final all = await col.get();
    final matches = all.docs.where((d) {
      final data = d.data();
      final candidates = <String?>[
        data['name'] as String?,
        data['producent'] as String?,
        data['description'] as String?,
        data['sku'] as String?,
        data['barcode'] as String?,
        data['category'] as String?,
      ];
      return matchesSearch(norm, candidates);
    }).toList();

    debugPrint(
      'searchStockItems("$query") -> normalized="$norm", found ${matches.length} itemIds: ${matches.map((d) => d.id).toList()}',
    );
    return matches;
  }

  static Future<String?> resolveToSingleItemId(String input) async {
    final results = await searchStockItems(input);
    if (results.isEmpty) {
      debugPrint('resolveToSingleItemId("$input") -> no matches');
      return null;
    }
    if (results.length == 1) {
      debugPrint(
        'resolveToSingleItemId("$input") -> unique ${results.first.id}',
      );
      return results.first.id;
    }
    final lower = input.toLowerCase();
    for (final doc in results) {
      final name = (doc.data()['name'] as String?)?.toLowerCase() ?? '';
      if (name == lower) {
        debugPrint(
          'resolveToSingleItemId("$input") -> exact name match ${doc.id}',
        );
        return doc.id;
      }
    }
    debugPrint(
      'resolveToSingleItemId("$input") -> ambiguous, picking first ${results.first.id}',
    );
    return results.first.id;
  }

  // --- RW lookup with fallback fuzzy matching ---

  /// Returns a map containing 'rwDoc' and 'matchedLine' if found, else null.
  static Future<Map<String, dynamic>?> findLatestRwEntryForInput(
    String customerId,
    String projectId,
    String input, // could be itemId or free-text
  ) async {
    final col = FirebaseFirestore.instance
        .collection('customers')
        .doc(customerId)
        .collection('projects')
        .doc(projectId)
        .collection('rw_documents');
    final snap = await col.orderBy('createdAt', descending: true).get();

    // Direct itemId match first
    for (final doc in snap.docs) {
      final items = (doc.data()['items'] as List).cast<Map<String, dynamic>>();
      if (items.any((m) => m['itemId'] == input)) {
        debugPrint(
          'findLatestRwEntryForInput: direct itemId match "$input" in doc ${doc.id}',
        );
        return {
          'rwDoc': doc,
          'matchedLine': items.firstWhere((m) => m['itemId'] == input),
        };
      }
    }

    // Fuzzy match against name/producent/description
    final norm = normalize(input);
    for (final doc in snap.docs) {
      final items = (doc.data()['items'] as List).cast<Map<String, dynamic>>();
      for (final line in items) {
        final name = (line['name'] as String?) ?? '';
        final producent = (line['producent'] as String?) ?? '';
        final description = (line['description'] as String?) ?? '';
        if (matchesSearch(norm, [name, producent, description])) {
          debugPrint(
            'findLatestRwEntryForInput: fuzzy match "$input" matched line name="$name" in doc ${doc.id}',
          );
          return {'rwDoc': doc, 'matchedLine': line};
        }
      }
    }

    debugPrint('findLatestRwEntryForInput: no match for "$input"');
    return null;
  }

  // Legacy wrapper (kept for compatibility)
  static Future<DocumentSnapshot<Map<String, dynamic>>?> findLatestRwWithItemId(
    String customerId,
    String projectId,
    String itemId,
  ) async {
    final result = await findLatestRwEntryForInput(
      customerId,
      projectId,
      itemId,
    );
    if (result == null) return null;
    return result['rwDoc'] as DocumentSnapshot<Map<String, dynamic>>;
  }

  /// Lookup
  static Future<Map<String, dynamic>> lookupItemDetails(String itemId) async {
    final doc = await FirebaseFirestore.instance
        .collection('stock_items')
        .doc(itemId)
        .get();
    if (!doc.exists) throw Exception('Produkt $itemId nie istnieje');
    final data = doc.data()!;
    return {
      'itemId': itemId,
      'name': data['name'] ?? '',
      'unit': data['unit'] ?? '',
      'description': data['description'] ?? '',
      'producent': data['producent'] ?? '',
    };
  }

  static Future<void> applySwap({
    required String customerId,
    required String projectId,
    required String oldItemId,
    required int oldQty,
    required String newItemId,
    required int newQty,
  }) async {
    final db = FirebaseFirestore.instance;
    final projRef = db
        .collection('customers')
        .doc(customerId)
        .collection('projects')
        .doc(projectId);

    final batch = db.batch();

    // --- old RW adjustment + restore ---
    final oldRwEntry = await findLatestRwEntryForInput(
      customerId,
      projectId,
      oldItemId,
    );
    if (oldRwEntry != null) {
      final oldRwDoc =
          oldRwEntry['rwDoc'] as DocumentSnapshot<Map<String, dynamic>>;
      final items = (oldRwDoc.data()!['items'] as List)
          .cast<Map<String, dynamic>>();
      final idx = items.indexWhere((m) => m['itemId'] == oldItemId);
      if (idx != -1) {
        final existing = Map<String, dynamic>.from(items[idx]);
        final existingQty = (existing['quantity'] as num).toInt();
        if (existingQty > oldQty) {
          existing['quantity'] = existingQty - oldQty;
          final newItems = List<Map<String, dynamic>>.from(items);
          newItems[idx] = existing;
          batch.update(oldRwDoc.reference, {'items': newItems});
        } else {
          batch.update(oldRwDoc.reference, {
            'items': FieldValue.arrayRemove([items[idx]]),
          });
        }
        batch.update(db.collection('stock_items').doc(oldItemId), {
          'quantity': FieldValue.increment(oldQty),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    // --- today's RW creation/update ---
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final tomorrow = startOfDay.add(const Duration(days: 1));
    final rwCol = projRef.collection('rw_documents');

    final todaySnap = await rwCol
        .where('type', isEqualTo: 'RW')
        .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
        .where('createdAt', isLessThan: tomorrow)
        .limit(1)
        .get();

    late DocumentReference<Map<String, dynamic>> todayRwRef;
    Map<String, dynamic> todayRwData = {};
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (todaySnap.docs.isEmpty) {
      final custDoc = await db.collection('customers').doc(customerId).get();
      final projDoc = await db
          .collection('customers')
          .doc(customerId)
          .collection('projects')
          .doc(projectId)
          .get();
      final customerName = custDoc.data()?['name'] ?? '';
      final projectName = projDoc.data()?['title'] ?? '';

      todayRwRef = rwCol.doc();
      todayRwData = {
        'id': todayRwRef.id,
        'type': 'RW',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentUserId,
        'createdDay': Timestamp.fromDate(
          DateTime.utc(now.year, now.month, now.day),
        ),
        'customerId': customerId,
        'customerName': customerName,
        'projectId': projectId,
        'projectName': projectName,
        'items': <Map<String, dynamic>>[],
      };
    } else {
      todayRwRef = todaySnap.docs.first.reference;
      todayRwData = Map<String, dynamic>.from(todaySnap.docs.first.data());
    }

    // --- add new item into today's RW ---
    final newItemDoc = await db.collection('stock_items').doc(newItemId).get();
    if (!newItemDoc.exists) {
      throw Exception('Produkt $newItemId nie istnieje');
    }
    final newItemData = newItemDoc.data()!;
    final existingItems = (todayRwData['items'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    final newIdx = existingItems.indexWhere((m) => m['itemId'] == newItemId);
    if (newIdx != -1) {
      final existing = Map<String, dynamic>.from(existingItems[newIdx]);
      final existingQty = (existing['quantity'] as num).toInt();
      existing['quantity'] = existingQty + newQty;
      final updatedItems = List<Map<String, dynamic>>.from(existingItems);
      updatedItems[newIdx] = existing;
      todayRwData['items'] = updatedItems;
    } else {
      final entry = {
        'itemId': newItemId,
        'name': newItemData['name'] ?? '',
        'description': newItemData['description'] ?? '',
        'quantity': newQty,
        'unit': newItemData['unit'] ?? '',
        'producent': newItemData['producent'] ?? '',
      };
      todayRwData['items'] = [...existingItems, entry];
    }

    if (todaySnap.docs.isEmpty) {
      batch.set(todayRwRef, todayRwData);
    } else {
      batch.update(todayRwRef, {
        'items': todayRwData['items'],
        'lastUpdatedAt': FieldValue.serverTimestamp(),
        'lastUpdatedBy': currentUserId,
      });
    }

    // Deduct new
    batch.update(db.collection('stock_items').doc(newItemId), {
      'quantity': FieldValue.increment(-newQty),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Sync project document
    final projSnapshot = await projRef.get();
    if (projSnapshot.exists) {
      final rwTypeItems =
          (todayRwData['items'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      final remaining = rwTypeItems
          .where((it) => (it['quantity'] as num).toInt() > 0)
          .map(
            (it) => {
              'itemId': it['itemId'],
              'quantity': it['quantity'],
              'unit': it['unit'],
              'name': it['name'] ?? '',
            },
          )
          .toList();
      batch.update(projRef, {
        'items': remaining,
        'lastRwDate': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
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
      'customerName': '',
      'createdBy': createdBy,
      'createdAt': createdAt,
      'createdDay': Timestamp.fromDate(createdDay),
      'type': type,
      'items': lines.map((l) {
        if (l.isStock) {
          final stock = allStockItems.firstWhere((s) => s.id == l.itemRef);
          return {
            'itemId': l.itemRef,
            'name': stock.name,
            'description': stock.description,
            'quantity': l.requestedQty,
            'unit': l.unit,
            'producent': stock.producent,
          };
        } else {
          return {
            'itemId': l.itemRef,
            'name': l.customName,
            'description': '',
            'quantity': l.requestedQty,
            'unit': l.unit,
          };
        }
      }).toList(),
    };
  }
}
