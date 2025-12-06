import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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

  static Future<Map<String, dynamic>?> findCurrentProjectLineForInput(
    String customerId,
    String projectId,
    String input,
  ) async {
    final db = FirebaseFirestore.instance;
    final projRef = db
        .collection('customers')
        .doc(customerId)
        .collection('projects')
        .doc(projectId);

    final projSnap = await projRef.get();
    final projData = projSnap.data();
    final items = ((projData?['items'] as List?) ?? const [])
        .cast<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    Map<String, dynamic>? current = items.firstWhere(
      (m) => m['itemId'] == input,
      orElse: () => {},
    );

    if (current.isEmpty) {
      final norm = normalize(input);
      for (final m in items) {
        final name = (m['name'] as String?) ?? '';
        final producent = (m['producent'] as String?) ?? '';
        final desc = (m['description'] as String?) ?? '';
        if (matchesSearch(norm, [name, producent, desc])) {
          current = m;
          break;
        }
      }
    }

    if (current!.isNotEmpty) {
      final rwDoc = await findLatestRwWithItemId(
        customerId,
        projectId,
        current['itemId'] as String,
      );
      return {'source': 'project', 'matchedLine': current, 'rwDoc': rwDoc};
    }

    final fallback = await findLatestRwEntryForInput(
      customerId,
      projectId,
      input,
    );
    if (fallback != null) {
      return {
        'source': 'rw',
        'matchedLine': Map<String, dynamic>.from(
          fallback['matchedLine'] as Map,
        ),
        'rwDoc': fallback['rwDoc'] as DocumentSnapshot<Map<String, dynamic>>,
      };
    }

    return null;
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

  static Future<Map<String, dynamic>?> findLatestRwEntryForInput(
    String customerId,
    String projectId,
    String input,
  ) async {
    final col = FirebaseFirestore.instance
        .collection('customers')
        .doc(customerId)
        .collection('projects')
        .doc(projectId)
        .collection('rw_documents');
    final snap = await col.orderBy('createdAt', descending: true).get();

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

  static Future<void> applySwapOnExistingRw({
    required DocumentReference<Map<String, dynamic>> sourceRwRef,
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

    final rwSnap = await sourceRwRef.get();
    if (!rwSnap.exists) throw Exception('Source RW missing');
    final rwData = Map<String, dynamic>.from(rwSnap.data()!);
    final items = (rwData['items'] as List).cast<Map<String, dynamic>>();

    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    String oldItemName = oldItemId;
    String newItemName = newItemId;

    // --- we will need these refs/snaps for safe updates ---
    final oldStockRef = db.collection('stock_items').doc(oldItemId);
    final oldStockSnap = await oldStockRef.get(); // may or may not exist

    DocumentSnapshot<Map<String, dynamic>>? newItemDoc;

    final oldMatch = items.firstWhere(
      (m) => m['itemId'] == oldItemId,
      orElse: () => {},
    );
    if (oldMatch.isNotEmpty) {
      final prod = (oldMatch['producent'] ?? '').toString();
      final name = (oldMatch['name'] ?? '').toString();
      oldItemName = prod.isNotEmpty ? '$prod $name' : name;
    } else if (oldStockSnap.exists) {
      final d = oldStockSnap.data()!;
      final prod = (d['producent'] ?? '').toString();
      final name = (d['name'] ?? '').toString();
      oldItemName = prod.isNotEmpty ? '$prod $name' : name;
    }

    final newMatch = items.firstWhere(
      (m) => m['itemId'] == newItemId,
      orElse: () => {},
    );
    if (newMatch.isNotEmpty) {
      final prod = (newMatch['producent'] ?? '').toString();
      final name = (newMatch['name'] ?? '').toString();
      newItemName = prod.isNotEmpty ? '$prod $name' : name;
    } else {
      newItemDoc = await db.collection('stock_items').doc(newItemId).get();
      if (newItemDoc.exists) {
        final d = newItemDoc.data()!;
        final prod = (d['producent'] ?? '').toString();
        final name = (d['name'] ?? '').toString();
        newItemName = prod.isNotEmpty ? '$prod $name' : name;
      }
    }

    // nic się nie zmienia -> nic nie rób
    if (oldItemId == newItemId && oldQty == newQty) {
      return;
    }

    // --------- PROJEKT + STAN MAGAZYNU ---------
    if (oldQty > 0) {
      final oldIdx = items.indexWhere((m) => m['itemId'] == oldItemId);
      if (oldIdx != -1) {
        final existing = Map<String, dynamic>.from(items[oldIdx]);
        final existingQty = (existing['quantity'] as num).toInt();
        if (existingQty > oldQty) {
          existing['quantity'] = existingQty - oldQty;
          items[oldIdx] = existing;
        } else {
          items.removeAt(oldIdx);
        }
      }

      // 🔴 kluczowa zmiana: aktualizuj stan tylko jeśli dokument istnieje
      if (oldStockSnap.exists) {
        batch.update(oldStockRef, {
          'quantity': FieldValue.increment(oldQty),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        debugPrint(
          'applySwapOnExistingRw: stock_items/$oldItemId missing – skipping stock revert',
        );
      }
    }

    if (newQty > 0) {
      newItemDoc ??= await db.collection('stock_items').doc(newItemId).get();
      if (!newItemDoc.exists) {
        throw Exception('Produkt $newItemId nie istnieje');
      }
      final newItemData = newItemDoc.data()!;

      final newIdx = items.indexWhere((m) => m['itemId'] == newItemId);
      if (newIdx != -1) {
        final existing = Map<String, dynamic>.from(items[newIdx]);
        final existingQty = (existing['quantity'] as num).toInt();
        existing['quantity'] = existingQty + newQty;
        items[newIdx] = existing;
      } else {
        items.add({
          'itemId': newItemId,
          'name': newItemData['name'] ?? '',
          'description': newItemData['description'] ?? '',
          'quantity': newQty,
          'unit': newItemData['unit'] ?? '',
          'producent': newItemData['producent'] ?? '',
        });
      }

      batch.update(db.collection('stock_items').doc(newItemId), {
        'quantity': FieldValue.increment(-newQty),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // --------- NOTATKA + UPDATE RW + PROJEKT ---------
    String action;
    String noteText;
    if (oldQty > 0 && newQty > 0) {
      action = 'Zamiana';
      noteText = '$oldQty x $oldItemName → $newQty x $newItemName';
    } else if (oldQty > 0 && newQty == 0) {
      action = 'Zwrot';
      noteText = '$oldQty x $oldItemName';
    } else if (oldQty == 0 && newQty > 0) {
      action = 'Zainstalowano';
      noteText = '$newQty x $newItemName';
    } else {
      action = 'Aktualizacja';
      noteText = '';
    }

    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    String userDisplayName = userId;
    try {
      final userSnap = await db.collection('users').doc(userId).get();
      final userData = userSnap.data();
      userDisplayName = userData?['name'] ?? userData?['email'] ?? userId;
    } catch (_) {}

    final noteEntry = {
      'createdAt': Timestamp.now(),
      'userName': userDisplayName,
      'text': noteText,
      'action': action,
    };

    final existingNotes = (rwData['notesList'] as List<dynamic>?) ?? [];
    final updatedNotes = [...existingNotes, noteEntry];

    batch.update(sourceRwRef, {
      'items': items,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
      'lastUpdatedBy': currentUserId,
      'notesList': updatedNotes,
    });

    batch.update(projRef, {
      'items': items
          .where((it) => (it['quantity'] as num).toInt() > 0)
          .map(
            (it) => {
              'itemId': it['itemId'],
              'quantity': it['quantity'],
              'unit': it['unit'],
              'name': it['name'] ?? '',
            },
          )
          .toList(),
      'lastRwDate': FieldValue.serverTimestamp(),
    });

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

  static Future<Map<String, dynamic>> enrichLineWithStock(
    Map<String, dynamic> line,
  ) async {
    final hasName = (line['name'] as String?)?.trim().isNotEmpty ?? false;
    final hasProd = (line['producent'] as String?)?.trim().isNotEmpty ?? false;
    final id = (line['itemId'] as String?) ?? '';
    if (id.isEmpty || (hasName && hasProd)) return line;

    final doc = await FirebaseFirestore.instance
        .collection('stock_items')
        .doc(id)
        .get();
    if (!doc.exists) return line;

    final d = doc.data()!;
    return {
      ...line,
      'name': line['name'] ?? (d['name'] ?? ''),
      'producent': line['producent'] ?? (d['producent'] ?? ''),
      'unit': line['unit'] ?? (d['unit'] ?? ''),
      'description': line['description'] ?? (d['description'] ?? ''),
    };
  }

  static Future<int> getInstalledQtyFromProject(
    String customerId,
    String projectId,
    String itemId,
  ) async {
    final projRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(customerId)
        .collection('projects')
        .doc(projectId);
    final snap = await projRef.get();
    final items = ((snap.data()?['items'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final m = items.firstWhere((x) => x['itemId'] == itemId, orElse: () => {});
    if (m.isEmpty) return 0;
    return ((m['quantity'] as num?)?.toInt() ?? 0);
  }

  static Future<void> applySwapAsNewRw({
    required DocumentReference<Map<String, dynamic>> sourceRwRef,
    required String customerId,
    required String projectId,
    required String oldItemId,
    required int oldQty,
    required String newItemId,
    required int newQty,
  }) async {
    final db = FirebaseFirestore.instance;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    final projRef = db
        .collection('customers')
        .doc(customerId)
        .collection('projects')
        .doc(projectId);
    final rwCol = projRef.collection('rw_documents');

    final custSnap = await db.collection('customers').doc(customerId).get();
    final customerName = (custSnap.data()?['name'] as String?) ?? '';

    String createdByName = '';
    try {
      final u = await db.collection('users').doc(uid).get();
      createdByName =
          (u.data()?['name'] as String?) ??
          (u.data()?['email'] as String?) ??
          '';
    } catch (_) {}

    String displayNameFor(String itemId, Map<String, dynamic>? fromLine) {
      if (fromLine != null) {
        final prod = (fromLine['producent'] ?? '').toString();
        final nm = (fromLine['name'] ?? '').toString();
        if (prod.isNotEmpty || nm.isNotEmpty) {
          return prod.isNotEmpty ? '$prod $nm' : nm;
        }
      }
      return itemId;
    }

    final src = await sourceRwRef.get();
    final srcItems = (src.data()?['items'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    Map<String, dynamic>? oldLine = srcItems.firstWhere(
      (m) => m['itemId'] == oldItemId,
      orElse: () => {},
    );
    Map<String, dynamic>? newLine = srcItems.firstWhere(
      (m) => m['itemId'] == newItemId,
      orElse: () => {},
    );
    if (oldLine.isEmpty) oldLine = null;
    if (newLine.isEmpty) newLine = null;

    String action;
    String noteText;
    if (oldQty > 0 && newQty > 0) {
      action = 'Zamiana';
      noteText =
          '$oldQty x ${displayNameFor(oldItemId, oldLine)} → $newQty x ${displayNameFor(newItemId, newLine)}';
    } else if (oldQty > 0 && newQty == 0) {
      action = 'Zwrot';
      noteText = '$oldQty x ${displayNameFor(oldItemId, oldLine)}';
    } else if (oldQty == 0 && newQty > 0) {
      action = 'Zainstalowano';
      noteText = '$newQty x ${displayNameFor(newItemId, newLine)}';
    } else {
      action = 'Aktualizacja';
      noteText = '';
    }

    final nowLocal = DateTime.now();
    final todayStart = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final todaysQuery = await rwCol
        .where('type', isEqualTo: 'RW')
        .where('createdAt', isGreaterThanOrEqualTo: todayStart)
        .where('createdAt', isLessThan: todayEnd)
        .limit(1)
        .get();

    final bool todaysExists = todaysQuery.docs.isNotEmpty;
    final DocumentReference<Map<String, dynamic>> todaysRef = todaysExists
        ? todaysQuery.docs.first.reference
        : rwCol.doc();

    final createdDayUtc = DateTime.utc(
      nowLocal.year,
      nowLocal.month,
      nowLocal.day,
    );

    await db.runTransaction((tx) async {
      // ---------- READS FIRST ----------
      final projSnap = await tx.get(projRef);
      final projData = projSnap.data() ?? <String, dynamic>{};

      // If we'll need the new item details, read them now
      final newRef = db.collection('stock_items').doc(newItemId);
      final newSnap = newQty > 0 ? await tx.get(newRef) : null;
      final Map<String, dynamic> newData = Map<String, dynamic>.from(
        newSnap?.data() ?? const {},
      );

      // If today's RW exists, read it now
      final todaysSnap = todaysExists ? await tx.get(todaysRef) : null;

      // ---------- PREPARE MUTABLE COPIES ----------
      final List<Map<String, dynamic>> projectItems =
          ((projData['items'] as List?) ?? const [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();

      int qtyOf(Map<String, dynamic> m) =>
          ((m['quantity'] as num?)?.toInt() ?? 0);

      // ---------- APPLY TO PROJECT / STOCK (WRITES, no more tx.get below) ----------
      if (oldQty > 0) {
        final idxOld = projectItems.indexWhere((m) => m['itemId'] == oldItemId);
        if (idxOld != -1) {
          final existing = Map<String, dynamic>.from(projectItems[idxOld]);
          final after = qtyOf(existing) - oldQty;
          if (after > 0) {
            existing['quantity'] = after;
            projectItems[idxOld] = existing;
          } else {
            projectItems.removeAt(idxOld);
          }
        }
        tx.update(db.collection('stock_items').doc(oldItemId), {
          'quantity': FieldValue.increment(oldQty),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (newQty > 0) {
        final idxNew = projectItems.indexWhere((m) => m['itemId'] == newItemId);
        if (idxNew != -1) {
          final existing = Map<String, dynamic>.from(projectItems[idxNew]);
          existing['quantity'] = qtyOf(existing) + newQty;
          projectItems[idxNew] = existing;
        } else {
          projectItems.add({
            'itemId': newItemId,
            'name': newData['name'] ?? '',
            'description': newData['description'] ?? '',
            'quantity': newQty,
            'unit': newData['unit'] ?? '',
            'producent': newData['producent'] ?? '',
          });
        }

        tx.update(newRef, {
          'quantity': FieldValue.increment(-newQty),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      tx.update(projRef, {
        'items': projectItems,
        'lastRwDate': FieldValue.serverTimestamp(),
      });

      // ---------- NOTES + TODAY'S RW ----------
      final noteEntry = {
        'createdAt': Timestamp.now(),
        'userName': createdByName.isEmpty ? uid : createdByName,
        'text': noteText,
        'action': action,
      };

      if (todaysExists) {
        final List<Map<String, dynamic>> rwItems =
            ((todaysSnap!.data()?['items'] as List?) ?? const [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();

        if (oldQty > 0) {
          final i = rwItems.indexWhere((m) => m['itemId'] == oldItemId);
          if (i != -1) {
            final m = Map<String, dynamic>.from(rwItems[i]);
            final after = qtyOf(m) - oldQty;
            if (after > 0) {
              m['quantity'] = after;
              rwItems[i] = m;
            } else {
              rwItems.removeAt(i);
            }
          }
        }

        if (newQty > 0) {
          final i = rwItems.indexWhere((m) => m['itemId'] == newItemId);
          if (i != -1) {
            final m = Map<String, dynamic>.from(rwItems[i]);
            m['quantity'] = qtyOf(m) + newQty;
            rwItems[i] = m;
          } else {
            rwItems.add({
              'itemId': newItemId,
              'name': newData['name'] ?? '',
              'description': newData['description'] ?? '',
              'quantity': newQty,
              'unit': newData['unit'] ?? '',
              'producent': newData['producent'] ?? '',
            });
          }
        }

        tx.update(todaysRef, {
          'items': rwItems.where((m) => qtyOf(m) > 0).toList(),
          'lastUpdatedAt': FieldValue.serverTimestamp(),
          'lastUpdatedBy': uid,
          'notesList': FieldValue.arrayUnion([noteEntry]),
        });
      } else {
        tx.set(todaysRef, {
          'id': todaysRef.id,
          'customerId': customerId,
          'customerName': customerName,
          'projectId': projectId,
          'projectName':
              (projData['projectName']?.toString() ??
                      projData['name']?.toString() ??
                      projData['title']?.toString() ??
                      '')
                  .trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'createdDay': Timestamp.fromDate(
            DateTime.utc(nowLocal.year, nowLocal.month, nowLocal.day),
          ),
          'createdBy': uid,
          'createdByName': createdByName,
          'type': 'RW',
          'sourceRwId': sourceRwRef.id,
          'items': projectItems.where((m) => qtyOf(m) > 0).toList(),
          'notesList': [noteEntry],
        });
      }
    });
  }
}
