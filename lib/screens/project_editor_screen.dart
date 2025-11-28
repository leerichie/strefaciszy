// lib/screens/project_editor_screen.dart

import 'dart:async';
import 'dart:core';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:strefa_ciszy/models/project_line.dart';
import 'package:strefa_ciszy/models/stock_item.dart';
import 'package:strefa_ciszy/offline/reservations_offline.dart';
import 'package:strefa_ciszy/screens/project_description_screen.dart';
import 'package:strefa_ciszy/screens/rw_documents_screen.dart';
import 'package:strefa_ciszy/services/admin_api.dart';
import 'package:strefa_ciszy/services/api_service.dart';
import 'package:strefa_ciszy/services/audit_service.dart';
import 'package:strefa_ciszy/services/stock_service.dart';
import 'package:strefa_ciszy/services/storage_service.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';
import 'package:strefa_ciszy/widgets/note_dialogue.dart';
import 'package:strefa_ciszy/widgets/notes_section.dart';
import 'package:strefa_ciszy/widgets/project_line_dialog.dart';

class NoSwipeCupertinoRoute<T> extends CupertinoPageRoute<T> {
  NoSwipeCupertinoRoute({required super.builder});

  @override
  bool get popGestureEnabled => false;
}

class ProjectEditorScreen extends StatefulWidget {
  final bool isAdmin;
  final String customerId;
  final String projectId;
  final String? rwId;
  final DateTime? rwCreatedAt;

  const ProjectEditorScreen({
    super.key,
    required this.customerId,
    required this.projectId,
    required this.isAdmin,
    this.rwId,
    this.rwCreatedAt,
  });

  @override
  _ProjectEditorScreenState createState() => _ProjectEditorScreenState();
}

class _ProjectEditorScreenState extends State<ProjectEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  final _storage = StorageService();
  final List<String> _imageUrls = [];
  final List<String> _localPreviews = [];
  List<Note> _notes = [];

  bool _loading = true;
  bool _saving = false;
  bool _initialized = false;
  bool _rwExistsToday = false;
  bool _mmExistsToday = false;

  String _title = '';
  String _status = 'draft';
  List<XFile> _images = [];
  String _customerName = '';

  static const bool kUseFirestoreStock = false;

  StreamSubscription<QuerySnapshot<StockItem>>? _stockSub;

  List<StockItem> _stockItems = [];
  int _stockOffset = 0;
  bool _stockHasMore = true;
  List<ProjectLine> _lines = [];
  late final bool _rwLocked;

  late final StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>
  _notesSub;
  Timer? _midnightRolloverTimer;
  final Map<String, int> _serverAvail = {};

  @override
  void initState() {
    super.initState();

    FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .get()
        .then((snap) {
          if (snap.exists) {
            setState(() {
              _customerName = snap.data()!['name'] as String? ?? '';
            });
          }
        });

    final today = DateTime.now();
    final created = widget.rwCreatedAt;
    _rwLocked =
        !widget.isAdmin &&
        created != null &&
        (created.year != today.year ||
            created.month != today.month ||
            created.day != today.day);

    // _stockSub = FirebaseFirestore.instance
    //     .collection('stock_items')
    //     .withConverter<StockItem>(
    //       fromFirestore: (snap, _) => StockItem.fromMap(snap.data()!, snap.id),
    //       toFirestore: (item, _) => item.toMap(),
    //     )
    //     .snapshots()
    //     .listen((snap) {
    //       setState(() => _stockItems = snap.docs.map((d) => d.data()).toList());
    //     });
    if (kUseFirestoreStock) {
      _stockSub = FirebaseFirestore.instance
          .collection('stock_items')
          .withConverter<StockItem>(
            fromFirestore: (snap, _) =>
                StockItem.fromMap(snap.data()!, snap.id),
            toFirestore: (item, _) => item.toMap(),
          )
          .snapshots()
          .listen((snap) {
            setState(
              () => _stockItems = snap.docs.map((d) => d.data()).toList(),
            );
          });
    } else {
      // Initial load from API (first page)
      _loadStockFromApi(reset: true);
    }
    //////////

    final projRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId);

    _notesSub = projRef.snapshots().listen((snap) {
      if (!mounted) return;
      if (!snap.exists) return;

      final data = snap.data()!;

      final rawNotes = (data['notesList'] as List<dynamic>?) ?? const [];
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final todaysRaw = rawNotes
          .where((m) {
            final ts = (m['createdAt'] as Timestamp).toDate();
            return !ts.isBefore(startOfDay) && ts.isBefore(endOfDay);
          })
          .cast<Map<String, dynamic>>()
          .toList();

      final todayNotes =
          todaysRaw
              .map(
                (m) => Note(
                  text: m['text'] as String,
                  userName: m['userName'] as String,
                  createdAt: (m['createdAt'] as Timestamp).toDate(),
                ),
              )
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final projItemsRaw = (data['items'] as List<dynamic>?) ?? const [];
      final freshLines = projItemsRaw
          .map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            final itemId = m['itemId'] as String? ?? '';
            final qty = (m['quantity'] as num?)?.toInt() ?? 0;
            final unit = m['unit'] as String? ?? '';
            final name = (m['name'] as String?) ?? '';

            // final isStock = _stockItems.any((s) => s.id == itemId);
            // final originalStock = isStock
            //     ? _stockItems.firstWhere((s) => s.id == itemId).quantity
            //     : qty;

            final idx = _stockItems.indexWhere((s) => s.id == itemId);
            final isStock = itemId.isNotEmpty;
            final originalStock = idx == -1 ? qty : _stockItems[idx].quantity;

            return ProjectLine(
              isStock: isStock,
              itemRef: itemId,
              customName: isStock ? '' : name,
              requestedQty: qty,
              previousQty: qty,
              originalStock: originalStock,
              unit: unit,
            );
          })
          .where((l) => l.requestedQty > 0)
          .toList();

      setState(() {
        _notes = todayNotes;
        _lines = freshLines;
        _title = (data['title'] as String?) ?? _title;
      });
    });

    _loadAll();
    _checkTodayExists('RW');
    _checkTodayExists('MM');
    _scheduleMidnightRollover();
  }

  @override
  void dispose() {
    _stockSub?.cancel();
    _notesSub.cancel();
    _midnightRolloverTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStockFromApi({bool reset = false}) async {
    if (reset) {
      _stockOffset = 0;
      _stockHasMore = true;
      _stockItems = [];
    }
    if (!_stockHasMore) return;

    // pull a chunk (tune size as you like)
    const int pageSize = 200;
    try {
      final page = await ApiService.fetchProductsPaged(
        limit: pageSize,
        offset: _stockOffset,
      );
      setState(() {
        _stockItems.addAll(page.items);
        _stockOffset = page.nextOffset;
        _stockHasMore = page.hasMore;
      });
    } catch (e) {
      debugPrint('API stock load failed: $e');
      // fail-soft: keep whatever we already have
    }
  }

  void _scheduleMidnightRollover() {
    final now = DateTime.now();
    final tomorrow = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: 1));
    final untilMidnight = tomorrow.difference(now);

    _midnightRolloverTimer = Timer(untilMidnight, () async {
      if (!mounted) return;

      await _saveRWDocument('RW');
      final rwRef = await _todayRwRef();
      if (rwRef != null) {
        await rwRef.update({
          'notesList': _notes
              .map(
                (n) => {
                  'text': n.text,
                  'userName': n.userName,
                  'createdAt': Timestamp.fromDate(n.createdAt),
                },
              )
              .toList(),
        });
      }
      await Future.delayed(Duration(seconds: 1));

      await _loadAll();

      await _checkTodayExists('RW');
      await _checkTodayExists('MM');

      _scheduleMidnightRollover();
    });
  }

  Future<void> _editProjectName() async {
    var newTitle = _title;
    final projRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zmień nazwa projektu'),
        content: TextField(
          autofocus: true,
          controller: TextEditingController(text: newTitle),
          decoration: const InputDecoration(hintText: 'Nowa nazwa'),
          onChanged: (v) => newTitle = v.trim(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () {
              if (newTitle.isNotEmpty && newTitle != _title) {
                projRef.update({'title': newTitle});
                setState(() => _title = newTitle);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
  }

  Future<DocumentReference<Map<String, dynamic>>?> _todayRwRef() async {
    final projRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId);

    final start = DateTime.now().toLocal();
    final startOfDay = DateTime(start.year, start.month, start.day);
    final endOfDay = startOfDay.add(Duration(days: 1));
    final snap = await projRef
        .collection('rw_documents')
        .where('type', isEqualTo: 'RW')
        .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
        .where('createdAt', isLessThan: endOfDay)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.reference;
  }

  Future<void> _loadAll() async {
    final projRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId);

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfTomorrow = startOfDay.add(const Duration(days: 1));

    final todaySnap = await projRef
        .collection('rw_documents')
        .where('type', isEqualTo: 'RW')
        .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
        .where('createdAt', isLessThan: startOfTomorrow)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (todaySnap.docs.isNotEmpty) {
      final data = todaySnap.docs.first.data();
      final rawItems = (data['items'] as List<dynamic>?) ?? [];

      _lines = rawItems
          .map((e) {
            final m = e as Map<String, dynamic>;
            final itemId = m['itemId'] as String? ?? '';
            final qty = (m['quantity'] as num?)?.toInt() ?? 0;
            final unit = m['unit'] as String? ?? '';
            final name = m['name'] as String? ?? '';
            // final isStock = _stockItems.any((s) => s.id == itemId);

            // final originalStock = isStock
            //     ? _stockItems.firstWhere((s) => s.id == itemId).quantity
            //     : qty;

            final idx = _stockItems.indexWhere((s) => s.id == itemId);
            final isStock = itemId.isNotEmpty;
            final originalStock = idx == -1 ? qty : _stockItems[idx].quantity;

            return ProjectLine(
              isStock: isStock,
              itemRef: itemId,
              customName: isStock ? '' : name,
              requestedQty: qty,
              originalStock: originalStock,
              previousQty: qty,
              unit: unit,
            );
          })
          .where((l) => l.requestedQty > 0)
          .toList();

      _title = data['projectName'] as String? ?? '';

      setState(() {
        _loading = false;
        _initialized = true;
      });
      return;
    }

    final snap = await projRef.get();
    if (!snap.exists) {
      setState(() {
        _lines = [];
        _title = '';
        _status = 'draft';
        _images = [];
        _loading = false;
        _initialized = true;
      });
      return;
    }

    final data = snap.data() ?? <String, dynamic>{};
    final lastRwRaw = data['lastRwDate'];
    DateTime? lastRwDate = lastRwRaw is Timestamp ? lastRwRaw.toDate() : null;

    if (lastRwDate == null || lastRwDate.isBefore(startOfDay)) {
      await projRef.update({
        'items': <Map<String, dynamic>>[],
        'status': 'draft',
      });
      _lines = [];
    } else {
      _lines = (data['items'] as List<dynamic>? ?? [])
          .map((m) => ProjectLine.fromMap(m))
          .where((l) => l.requestedQty > 0)
          .toList();
    }

    _title = data['title'] as String? ?? '';
    _status = data['status'] as String? ?? 'draft';
    _images = ((data['images'] as List<dynamic>?) ?? [])
        .cast<String>()
        .map((u) => XFile(u))
        .toList();

    setState(() {
      _loading = false;
      _initialized = true;
    });
  }

  Future<void> _checkTodayExists(String type) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfTomorrow = startOfDay.add(Duration(days: 1));

    final dayStamp = Timestamp.fromDate(
      DateTime(now.year, now.month, now.day).toUtc(),
    );

    final snap = await FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId)
        .collection('rw_documents')
        .where('type', isEqualTo: type)
        .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
        .where('createdAt', isLessThan: startOfTomorrow)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    setState(() {
      if (type == 'RW') {
        _rwExistsToday = snap.docs.isNotEmpty;
      } else /* 'MM' */ {
        _mmExistsToday = snap.docs.isNotEmpty;
      }
    });
  }

  Future<void> _saveRWDocument(String type) async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String createdByName = user.displayName ?? '';
    if (createdByName.isEmpty) {
      final u = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      createdByName = (u.data()?['name'] as String?) ?? user.email ?? '—';
    }

    final custSnap = await FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .get();
    final customerName =
        custSnap.data()?['name'] as String? ?? '<nieznany klient>';

    final projSnap = await FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId)
        .get(const GetOptions(source: Source.server));
    final projectName =
        projSnap.data()?['title'] as String? ?? '<nieznany projekt>';

    final fullLines = List<ProjectLine>.from(_lines);
    final filteredLines = fullLines.where((l) => l.requestedQty > 0).toList();

    setState(() => _saving = true);

    // api reserve
    try {
      await AdminApi.init();
      final actorEmail = FirebaseAuth.instance.currentUser?.email ?? 'app';

      for (final ln in filteredLines.where((l) => l.isStock)) {
        final res = await reserveOrEnqueue(
          projectId: widget.projectId,
          customerId: widget.customerId,
          itemId: ln.itemRef,
          qty: ln.requestedQty,
          actorEmail: actorEmail,
        );

        if (!res.enqueued && res.server != null) {
          final afterStr =
              res.server!['available_after'] ??
              res.server!['availableAfter'] ??
              res.server!['available'];
          final after = int.tryParse(afterStr?.toString() ?? '');
          if (after != null) _serverAvail[ln.itemRef] = after;
        } else {
          // queued for later (offline) — optional toast, keep it quiet if you prefer
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Rezerwacja zapisana offline — zsynchronizuję później.',
                ),
              ),
            );
          }
        }
        if (mounted) setState(() {});
      }

      for (final ln in fullLines.where(
        (l) => l.isStock && (l.previousQty ?? 0) > 0 && l.requestedQty <= 0,
      )) {
        final res = await reserveOrEnqueue(
          projectId: widget.projectId,
          customerId: widget.customerId,
          itemId: ln.itemRef,
          qty: 0,
          actorEmail: actorEmail,
        );

        if (!res.enqueued && res.server != null) {
          final afterStr =
              res.server!['available_after'] ??
              res.server!['availableAfter'] ??
              res.server!['available'];
          final after = int.tryParse(afterStr?.toString() ?? '');
          if (after != null) _serverAvail[ln.itemRef] = after;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Zwolnienie rezerwacji zapisane offline.'),
              ),
            );
          }
        }
        if (mounted) setState(() {});
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Rezerwacja nie udany: $e')));
      }
      return;
    }
    ////

    final projectRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId);
    final rwCol = projectRef.collection('rw_documents');

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfTomorrow = startOfDay.add(Duration(days: 1));
    final todaySnap = await rwCol
        .where('type', isEqualTo: type)
        .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
        .where('createdAt', isLessThan: startOfTomorrow)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    final existsToday = todaySnap.docs.isNotEmpty;
    final rwId = existsToday ? todaySnap.docs.first.id : rwCol.doc().id;
    final rwRef = rwCol.doc(rwId);

    final docSnap = await rwRef.get();
    if (docSnap.exists) {
      final createdAtRaw = (docSnap.data()!['createdAt'] as Timestamp).toDate();
      if (createdAtRaw.isBefore(startOfDay) && !widget.isAdmin) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tylko administrator może edytować.')),
        );
        setState(() => _saving = false);
        return;
      }
    }

    DateTime createdAt = now;
    String createdBy = user.uid;
    if (docSnap.exists) {
      final data = docSnap.data()!;
      final rawTs = data['createdAt'];
      createdAt = rawTs is Timestamp ? rawTs.toDate() : createdAt;
      createdBy = data['createdBy'] ?? createdBy;
    }

    final rwData = StockService.buildRwDocMap(
      rwId,
      widget.projectId,
      _title,
      createdBy,
      createdAt,
      type,
      filteredLines,
      _stockItems,
      widget.customerId,
    );

    rwData['customerName'] = _customerName;
    rwData['projectName'] = projectName;
    rwData['createdByName'] = createdByName;

    rwData['notesList'] = _notes
        .map(
          (note) => {
            'text': note.text,
            'userName': note.userName,
            'createdAt': Timestamp.fromDate(note.createdAt),
          },
        )
        .toList();

    if (!existsToday) {
      rwData['createdAt'] = FieldValue.serverTimestamp();
      rwData['createdBy'] = user.uid;
    } else {
      rwData['lastUpdatedAt'] = FieldValue.serverTimestamp();
      rwData['lastUpdatedBy'] = user.uid;
    }

    // Debug diffs
    for (var ln in filteredLines) {
      ln.previousQty ??= 0;
      debugPrint(
        '   • ${ln.itemRef}: requestedQty=${ln.requestedQty}, previousQty=${ln.previousQty}',
      );
    }

    // DELETE-ALL
    if (filteredLines.isEmpty && docSnap.exists) {
      if (kUseFirestoreStock) {
        for (final ln in fullLines.where(
          (l) => l.previousQty > 0 && l.isStock,
        )) {
          try {
            await StockService.increaseQty(ln.itemRef, ln.previousQty);
            debugPrint('🔄 Restored ${ln.previousQty} for ${ln.itemRef}');
          } catch (e) {
            debugPrint('⚠️ Couldn\'t restore ${ln.itemRef}: $e');
          }
        }
      }

      try {
        await AdminApi.init();
        final actorEmail = FirebaseAuth.instance.currentUser?.email ?? 'app';
        for (final ln in fullLines.where(
          (l) => l.isStock && (l.previousQty ?? 0) > 0,
        )) {
          await reserveOrEnqueue(
            projectId: widget.projectId,
            customerId: widget.customerId,
            itemId: ln.itemRef,
            qty: 0,
            actorEmail: actorEmail,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Nie udało się cofać rezerwacji: $e')),
          );
        }
      }

      // if (kUseFirestoreStock) {
      //   for (final ln in fullLines.where(
      //     (l) => l.previousQty > 0 && l.isStock,
      //   )) {
      //     try {
      //       await StockService.increaseQty(ln.itemRef, ln.previousQty);
      //       debugPrint('🔄 Restored ${ln.previousQty} for ${ln.itemRef}');
      //     } catch (e) {
      //       debugPrint('⚠️ Couldn\'t restore ${ln.itemRef}: $e');
      //     }
      //   }
      // }
      ////
      final custSnap2 = await FirebaseFirestore.instance
          .collection('customers')
          .doc(widget.customerId)
          .get();
      final customerName2 = custSnap2.data()?['name'] as String? ?? '–';

      final projSnap2 = await FirebaseFirestore.instance
          .collection('customers')
          .doc(widget.customerId)
          .collection('projects')
          .doc(widget.projectId)
          .get();
      final projectName2 = projSnap2.data()?['title'] as String? ?? '–';

      for (final ln in fullLines.where((l) => l.previousQty > 0)) {
        final stock = _stockItems.firstWhereOrNull((s) => s.id == ln.itemRef);
        final name = stock?.name ?? ln.itemRef;

        final changeText = '-${ln.previousQty}${ln.unit}';

        await AuditService.logAction(
          action: 'Usunięto Raport',
          customerId: widget.customerId,
          projectId: widget.projectId,
          details: {
            '•': customerName2,
            '•': projectName2,
            '•': name,
            '•': changeText,
          },
        );
      }

      await rwRef.delete();
      debugPrint('🗑️ Raport $rwId usunięto (empty list)');

      await projectRef.update({
        'items': <Map<String, dynamic>>[],
        'status': 'draft',
        'lastRwDate': FieldValue.serverTimestamp(),
      });

      setState(() {
        _lines.clear();
        _rwExistsToday = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Usunięto pusty $type i przywrócono stan magazynowy'),
        ),
      );
      setState(() => _saving = false);
      return;
    }

    //  CREATE/UPDATE
    try {
      final batch = FirebaseFirestore.instance.batch();

      // for (var ln in filteredLines) {
      //   final prev = ln.previousQty ?? 0;
      //   final diff = ln.requestedQty - prev;
      //   if (diff != 0) {
      //     final stockRef = FirebaseFirestore.instance
      //         .collection('stock_items')
      //         .doc(ln.itemRef);
      //     batch.update(stockRef, {'quantity': FieldValue.increment(-diff)});
      //   }
      // }
      if (kUseFirestoreStock) {
        for (var ln in filteredLines) {
          final prev = ln.previousQty ?? 0;
          final diff = ln.requestedQty - prev;
          if (diff != 0 && ln.isStock) {
            final stockRef = FirebaseFirestore.instance
                .collection('stock_items')
                .doc(ln.itemRef);
            batch.update(stockRef, {'quantity': FieldValue.increment(-diff)});
          }
        }
      }
      //////

      if (existsToday) {
        final updateMap = {
          'items': rwData['items'],
          'lastUpdatedAt': FieldValue.serverTimestamp(),
          'lastUpdatedBy': user.uid,
        };
        batch.update(rwRef, updateMap);
      } else {
        batch.set(rwRef, rwData);
      }

      await batch.commit();

      await projectRef.update({
        'items': filteredLines.map((ln) {
          if (ln.isStock) {
            final s = _stockItems.firstWhereOrNull((x) => x.id == ln.itemRef);
            return {
              'itemId': ln.itemRef,
              'quantity': ln.requestedQty,
              'unit': ln.unit,
              'name': s?.name,
              'producer': s?.producent ?? '',
            };
          } else {
            return {
              'itemId': ln.itemRef,
              'quantity': ln.requestedQty,
              'unit': ln.unit,
              'name': ln.customName,
              'producer': '',
            };
          }
        }).toList(),

        'lastRwDate': FieldValue.serverTimestamp(),
      });

      final movedLines = filteredLines.where((ln) {
        final prev = ln.previousQty ?? 0;
        return ln.requestedQty - prev != 0;
      });

      for (final ln in movedLines) {
        final prev = ln.previousQty ?? 0;
        final diff = ln.requestedQty - prev;
        final name = ln.isStock
            ? _stockItems.firstWhereOrNull((s) => s.id == ln.itemRef)?.name
            : ln.customName;
        final changeText = '${diff > 0 ? '+' : ''}$diff${ln.unit}';

        final s = ln.isStock
            ? _stockItems.firstWhereOrNull((x) => x.id == ln.itemRef)
            : null;
        final producent = ln.isStock ? (s?.producent ?? '') : '';
        final productName = ln.isStock ? (s?.name ?? '') : ln.customName;
        final lineText = [
          producent,
          productName,
          changeText,
        ].where((e) => e.isNotEmpty).join(' ');

        await AuditService.logAction(
          action: existsToday ? 'Zaktualizowano Raport' : 'Utworzono Raport',
          customerId: widget.customerId,
          projectId: widget.projectId,
          details: {'•': lineText},
        );
      }

      setState(() {
        for (var ln in _lines) {
          final matching = filteredLines.firstWhere(
            (f) => f.itemRef == ln.itemRef,
            orElse: () => ln,
          );
          if (ln.itemRef == matching.itemRef) {
            ln.previousQty = matching.requestedQty;
          }
        }
      });

      await _checkTodayExists(type);
    } catch (e, st) {
      debugPrint('🔥 _saveRaportDocument failed: $e\n$st');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Błąd: ${e.toString()}')));
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _deleteLineFromRW(ProjectLine line) async {
    final projectRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId);
    final rwCol = projectRef.collection('rw_documents');

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final tomorrow = startOfDay.add(Duration(days: 1));

    final todaySnap = await rwCol
        .where('type', isEqualTo: 'RW')
        .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
        .where('createdAt', isLessThan: tomorrow)
        .limit(1)
        .get();

    if (todaySnap.docs.isEmpty) {
      return;
    }

    final rwDoc = todaySnap.docs.first;
    final rwId = rwDoc.id;
    final data = rwDoc.data();
    final materials = List<Map<String, dynamic>>.from(data['items'] ?? []);

    final updated = materials.where((m) {
      if (line.isStock) return m['itemId'] != line.itemRef;
      return m['name'] != line.customName;
    }).toList();

    if (kUseFirestoreStock && line.isStock) {
      final stockRef = FirebaseFirestore.instance
          .collection('stock_items')
          .doc(line.itemRef);
      await stockRef.update({
        'quantity': FieldValue.increment(line.requestedQty),
      });
    }

    // ---  reservation via API
    if (line.isStock) {
      try {
        await AdminApi.init();
        final email = FirebaseAuth.instance.currentUser?.email ?? 'app';
        final res = await reserveOrEnqueue(
          projectId: widget.projectId,
          customerId: widget.customerId,
          itemId: line.itemRef,
          qty: 0,
          actorEmail: email,
        );

        if (!res.enqueued && res.server != null) {
          final afterStr =
              res.server!['available_after'] ??
              res.server!['availableAfter'] ??
              res.server!['available'];
          final after = int.tryParse(afterStr?.toString() ?? '');
          if (after != null && mounted) {
            setState(() => _serverAvail[line.itemRef] = after);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Zwolnienie rezerwacji zapisane offline.'),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Zwolnienia rezerwacji nie udany: $e')),
          );
        }
      }
    }

    final s = line.isStock
        ? _stockItems.firstWhereOrNull((x) => x.id == line.itemRef)
        : null;
    final producent = line.isStock ? (s?.producent ?? '') : '';
    final productName = line.isStock ? (s?.name ?? '') : line.customName;
    final lineText = [
      producent,
      productName,
      '-${line.requestedQty}${line.unit}',
    ].where((e) => e.isNotEmpty).join(' ');

    await AuditService.logAction(
      action: 'Usunięto produkt',
      customerId: widget.customerId,
      projectId: widget.projectId,
      details: {'•': lineText},
    );

    if (updated.isEmpty) {
      await rwCol.doc(rwId).delete();

      await AuditService.logAction(
        action: 'Usunięto RW',
        customerId: widget.customerId,
        projectId: widget.projectId,
        details: {'RWId': rwId},
      );

      setState(() => _rwExistsToday = false);
    } else {
      await rwCol.doc(rwId).update({'items': updated});
    }

    final projSnap = await projectRef.get();
    if (projSnap.exists) {
      final projItems = List<Map<String, dynamic>>.from(
        projSnap.data()?['items'] ?? [],
      );
      final newProjItems = projItems.where((m) {
        if (line.isStock) return m['itemId'] != line.itemRef;
        return m['name'] != line.customName;
      }).toList();
      await projectRef.update({'items': newProjItems});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Ładowanie...')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final projRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId);

    final titleGest = GestureDetector(
      onTap: widget.isAdmin ? _editProjectName : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AutoSizeText(
            _customerName,
            style: TextStyle(color: Colors.black),
            maxLines: 1,
            minFontSize: 8,
          ),
          AutoSizeText(
            _title,
            style: TextStyle(color: Colors.red.shade900),
            maxLines: 1,
            minFontSize: 8,
          ),
        ],
      ),
    );

    return AppScaffold(
      centreTitle: true,
      title: '',
      showBackOnWeb: true,
      titleWidget: titleGest,

      actions: [Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0))],

      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  if (_rwLocked)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Dokument RW jest zablokowany do edycji.',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  Divider(),

                  // --- NOTES
                  NotesSection(
                    notes: _notes,

                    onAddNote: (ctx) async {
                      final authUser = FirebaseAuth.instance.currentUser!;
                      String userName = authUser.displayName ?? '';
                      if (userName.isEmpty) {
                        final userDoc = await FirebaseFirestore.instance
                            .collection('users')
                            .doc(authUser.uid)
                            .get();
                        userName =
                            userDoc.data()?['name'] as String? ??
                            authUser.email!;
                      }
                      final result = await showNoteDialog(
                        ctx,
                        userName: userName,
                      );
                      if (result == null) return null;

                      final noteMap = {
                        'text': result.trim(),
                        'userName': userName,
                        'createdAt': Timestamp.now(),
                      };

                      await projRef.update({
                        'notesList': FieldValue.arrayUnion([noteMap]),
                      });
                      final rwRef = await _todayRwRef();
                      if (rwRef != null) {
                        await rwRef.update({
                          'notesList': FieldValue.arrayUnion([noteMap]),
                        });
                      } else {
                        final now = DateTime.now();
                        final newRwRef = projRef
                            .collection('rw_documents')
                            .doc();
                        await newRwRef.set({
                          'type': 'RW',
                          'customerId': widget.customerId,
                          'projectId': widget.projectId,
                          'customerName': _customerName,
                          'projectName': _title,
                          'createdDay': DateTime(now.year, now.month, now.day),
                          'createdAt': FieldValue.serverTimestamp(),
                          'createdBy': authUser.uid,
                          'createdByName': userName,
                          'items': <Map<String, dynamic>>[],
                          'notesList': [noteMap],
                        });
                      }
                      await AuditService.logAction(
                        action: 'Zapisana notatka',
                        customerId: widget.customerId,
                        projectId: widget.projectId,
                        details: {'Notatka': result.trim()},
                      );

                      return null;
                    },

                    onEdit: (i, _) async {
                      final old = _notes[i];
                      final existingText = old.text;
                      final updated = await showNoteDialog(
                        context,
                        userName: old.userName,
                        createdAt: old.createdAt,
                        initial: existingText,
                      );
                      if (updated == null || updated.trim() == existingText) {
                        return;
                      }

                      final oldMap = {
                        'text': old.text,
                        'userName': old.userName,
                        'createdAt': Timestamp.fromDate(old.createdAt),
                      };

                      final authUser = FirebaseAuth.instance.currentUser!;
                      String userName = authUser.displayName ?? '';
                      if (userName.isEmpty) {
                        final userDoc = await FirebaseFirestore.instance
                            .collection('users')
                            .doc(authUser.uid)
                            .get();
                        userName =
                            userDoc.data()?['name'] as String? ??
                            authUser.email!;
                      }
                      final newMap = {
                        'text': updated.trim(),
                        'userName': userName,
                        'createdAt': Timestamp.now(),
                      };

                      await projRef.update({
                        'notesList': FieldValue.arrayRemove([oldMap]),
                      });
                      await projRef.update({
                        'notesList': FieldValue.arrayUnion([newMap]),
                      });

                      final rwRef2 = await _todayRwRef();
                      if (rwRef2 != null) {
                        await rwRef2.update({
                          'notesList': FieldValue.arrayRemove([oldMap]),
                        });
                        await rwRef2.update({
                          'notesList': FieldValue.arrayUnion([newMap]),
                        });
                      }
                      return;
                    },

                    onDelete: (i) async {
                      final note = _notes[i];

                      // Remove note from arrays
                      final map = {
                        'text': note.text,
                        'userName': note.userName,
                        'createdAt': Timestamp.fromDate(note.createdAt),
                      };
                      await projRef.update({
                        'notesList': FieldValue.arrayRemove([map]),
                      });
                      final rwRef3 = await _todayRwRef();
                      if (rwRef3 != null) {
                        await rwRef3.update({
                          'notesList': FieldValue.arrayRemove([map]),
                        });
                      }

                      await AuditService.logAction(
                        action: 'Usunięto notatka',
                        customerId: widget.customerId,
                        projectId: widget.projectId,
                        details: {'Notatka': note.text},
                      );
                    },
                  ),
                  Divider(),

                  if (_lines.any(
                    (l) =>
                        l.requestedQty > 0 && l.requestedQty != l.previousQty,
                  ))
                    Container(
                      padding: EdgeInsets.all(8),
                      margin: EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.orange),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Preview. Kliknij "Zapisz Raport" aby dodać do Raporty.',
                              style: TextStyle(color: Colors.orange[900]),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (_lines.isNotEmpty)
                    Expanded(
                      child: ListView.builder(
                        itemCount: _lines.length,

                        itemBuilder: (ctx, i) {
                          final today = DateTime.now();
                          final ln = _lines[i];
                          final stock = ln.isStock
                              ? _stockItems.firstWhereOrNull(
                                  (s) => s.id == ln.itemRef,
                                )
                              : null;

                          final producent = ln.isStock
                              ? (stock?.producent ?? '')
                              : '';
                          final name = ln.isStock
                              ? stock?.name ?? ''
                              : ln.customName;
                          final description = ln.isStock
                              ? (stock?.description ?? '')
                              : '';

                          final delta = ln.requestedQty - ln.previousQty;

                          final stockQty = ln.isStock
                              ? (stock?.quantity ?? ln.originalStock)
                              : ln.originalStock;

                          final int previewDefault = stockQty - delta;

                          // Prefer the server-reported availability if we have it
                          final int previewQty =
                              ln.isStock && _serverAvail.containsKey(ln.itemRef)
                              ? _serverAvail[ln.itemRef]!
                              : previewDefault;

                          final qtyColor = previewQty <= 0
                              ? Colors.red
                              : Colors.green;

                          final isToday =
                              ln.updatedAt == null ||
                              (ln.updatedAt!.year == today.year &&
                                  ln.updatedAt!.month == today.month &&
                                  ln.updatedAt!.day == today.day);

                          final isSynced =
                              ln.requestedQty == ln.previousQty &&
                              ln.requestedQty > 0;
                          final isLineLocked =
                              _rwLocked || (!isToday && !widget.isAdmin);

                          if (i.isEven) {
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 0),
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 2,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: ListTile(
                                  dense: true,
                                  tileColor: Colors.transparent,
                                  selectedTileColor: Colors.transparent,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 0,
                                    vertical: 0,
                                  ),
                                  title: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (producent.isNotEmpty)
                                        Text(
                                          producent,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      Text(
                                        name,
                                        style: TextStyle(fontSize: 14),
                                      ),
                                      if (description.isNotEmpty)
                                        Text(
                                          description,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[700],
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Text.rich(
                                    TextSpan(
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                      children: [
                                        TextSpan(
                                          text:
                                              '${ln.requestedQty} ${ln.unit} ',
                                        ),
                                        TextSpan(
                                          text: '(stan: $previewQty)',
                                          style: TextStyle(color: qtyColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isSynced)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 0,
                                            vertical: 0,
                                          ),
                                          margin: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          child: Icon(
                                            Icons.check_box,
                                            color: Colors.green,
                                          ),
                                        ),
                                      // IconButton(
                                      //   icon: Icon(
                                      //     Icons.edit,
                                      //     color: isLineLocked
                                      //         ? Colors.grey
                                      //         : Colors.blue,
                                      //   ),
                                      //   onPressed: isLineLocked
                                      //       ? () {
                                      //           ScaffoldMessenger.of(
                                      //             context,
                                      //           ).showSnackBar(
                                      //             const SnackBar(
                                      //               content: Text(
                                      //                 'Tylko administrator może edytować',
                                      //               ),
                                      //             ),
                                      //           );
                                      //         }
                                      //       : () async {
                                      //           final updated =
                                      //               await showProjectLineDialog(
                                      //                 context,
                                      //                 _stockItems,
                                      //                 existing: ln,
                                      //               );
                                      //           if (updated != null) {
                                      //             setState(
                                      //               () => _lines[i] = updated,
                                      //             );
                                      //             try {
                                      //               await _saveRWDocument('RW');
                                      //             } catch (e) {
                                      //               ScaffoldMessenger.of(
                                      //                 context,
                                      //               ).showSnackBar(
                                      //                 SnackBar(
                                      //                   content: Text(
                                      //                     'Update Raport - nie udało się: $e',
                                      //                   ),
                                      //                 ),
                                      //               );
                                      //             }
                                      //           }
                                      //         },
                                      // ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete,
                                          color: isLineLocked
                                              ? Colors.grey
                                              : Colors.red,
                                        ),
                                        onPressed: isLineLocked
                                            ? () {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Tylko administrator może usuwać',
                                                    ),
                                                  ),
                                                );
                                              }
                                            : () async {
                                                final shouldDelete =
                                                    await showDialog<bool>(
                                                      context: context,
                                                      builder: (ctx) => AlertDialog(
                                                        title: Text(
                                                          'Usuń produkt?',
                                                        ),
                                                        content: Text(
                                                          '${ln.requestedQty}x $producent $name',
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  ctx,
                                                                  false,
                                                                ),
                                                            child: Text(
                                                              'Anuluj',
                                                            ),
                                                          ),
                                                          ElevatedButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  ctx,
                                                                  true,
                                                                ),
                                                            child: Text('Usuń'),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                if (shouldDelete != true) {
                                                  return;
                                                }
                                                final removedLine = _lines
                                                    .removeAt(i);
                                                setState(() {});
                                                try {
                                                  await _deleteLineFromRW(
                                                    removedLine,
                                                  );
                                                } catch (e) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Błąd usuwania: $e',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 0),

                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 0,
                                  vertical: 0,
                                ),
                                title: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (producent.isNotEmpty)
                                      Text(
                                        producent,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    Text(
                                      name,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    if (description.isNotEmpty)
                                      Text(
                                        description,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[700],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text.rich(
                                  TextSpan(
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                    children: [
                                      TextSpan(
                                        text: '${ln.requestedQty} ${ln.unit} ',
                                      ),
                                      TextSpan(
                                        text: '(stan: $previewQty)',
                                        style: TextStyle(color: qtyColor),
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isSynced)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 0,
                                          vertical: 0,
                                        ),
                                        margin: const EdgeInsets.only(right: 8),
                                        child: const Icon(
                                          Icons.check_box,
                                          color: Colors.green,
                                        ),
                                      ),
                                    // IconButton(
                                    //   icon: Icon(
                                    //     Icons.edit,
                                    //     color: isLineLocked
                                    //         ? Colors.grey
                                    //         : Colors.blue,
                                    //   ),
                                    //   onPressed: isLineLocked
                                    //       ? () {
                                    //           ScaffoldMessenger.of(
                                    //             context,
                                    //           ).showSnackBar(
                                    //             const SnackBar(
                                    //               content: Text(
                                    //                 'Tylko administrator może edytować',
                                    //               ),
                                    //             ),
                                    //           );
                                    //         }
                                    //       : () async {
                                    //           final updated =
                                    //               await showProjectLineDialog(
                                    //                 context,
                                    //                 _stockItems,
                                    //                 existing: ln,
                                    //               );
                                    //           if (updated != null) {
                                    //             setState(
                                    //               () => _lines[i] = updated,
                                    //             );
                                    //             try {
                                    //               await _saveRWDocument('RW');
                                    //             } catch (e) {
                                    //               ScaffoldMessenger.of(
                                    //                 context,
                                    //               ).showSnackBar(
                                    //                 SnackBar(
                                    //                   content: Text(
                                    //                     'Update RW - nie udało się: $e',
                                    //                   ),
                                    //                 ),
                                    //               );
                                    //             }
                                    //           }
                                    //         },
                                    // ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete,
                                        color: isLineLocked
                                            ? Colors.grey
                                            : Colors.red,
                                      ),
                                      onPressed: isLineLocked
                                          ? () {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Tylko administrator może usuwać',
                                                  ),
                                                ),
                                              );
                                            }
                                          : () async {
                                              final shouldDelete =
                                                  await showDialog<bool>(
                                                    context: context,
                                                    builder: (ctx) => AlertDialog(
                                                      title: const Text(
                                                        'Usuń produkt?',
                                                      ),
                                                      content: Text(
                                                        '${ln.requestedQty}x $producent $name',
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                ctx,
                                                                false,
                                                              ),
                                                          child: const Text(
                                                            'Anuluj',
                                                          ),
                                                        ),
                                                        ElevatedButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                ctx,
                                                                true,
                                                              ),
                                                          child: const Text(
                                                            'Usuń',
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                              if (shouldDelete != true) return;
                                              final removedLine = _lines
                                                  .removeAt(i);
                                              setState(() {});
                                              try {
                                                await _deleteLineFromRW(
                                                  removedLine,
                                                );
                                              } catch (e) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Błąd usuwania: $e',
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),

      floatingActionButton: _rwLocked
          ? null
          : FloatingActionButton(
              tooltip: 'Dodaj produkt',
              onPressed: () async {
                final existingLines = {
                  for (var ln in _lines)
                    if (ln.isStock) ln.itemRef: ln.requestedQty,
                };

                final newLine = await showProjectLineDialog(
                  context,
                  _stockItems,
                  customerId: widget.customerId,
                  projectId: widget.projectId,
                  isAdmin: widget.isAdmin,
                  existingLines: existingLines,
                );

                if (newLine == null) {
                  await _loadAll();
                  await _checkTodayExists('RW');
                  if (mounted) setState(() {});
                  return;
                }

                StockItem? picked;
                if (newLine.isStock) {
                  final idx = _stockItems.indexWhere(
                    (s) => s.id == newLine.itemRef,
                  );
                  if (idx != -1) {
                    picked = _stockItems[idx];
                  } else {
                    try {
                      picked = await ApiService.fetchProduct(newLine.itemRef);
                      if (picked != null) {
                        setState(() => _stockItems.add(picked!));
                      }
                    } catch (_) {}
                  }
                }

                final lineWithUnit = newLine.isStock
                    ? newLine.copyWith(
                        unit: (picked?.unit.isNotEmpty == true
                            ? picked!.unit
                            : 'szt'),
                      )
                    : newLine;

                final existingIndex = lineWithUnit.isStock
                    ? _lines.indexWhere(
                        (l) => l.isStock && l.itemRef == lineWithUnit.itemRef,
                      )
                    : _lines.indexWhere(
                        (l) =>
                            !l.isStock &&
                            l.customName.toLowerCase() ==
                                lineWithUnit.customName.toLowerCase(),
                      );

                if (existingIndex != -1) {
                  _lines[existingIndex] = lineWithUnit;
                } else {
                  _lines.add(lineWithUnit);
                }
                if (mounted) setState(() {});

                try {
                  await _saveRWDocument('RW');
                  await _loadAll();
                  await _checkTodayExists('RW');
                  if (mounted) setState(() {});
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Auto Sync RW - nie udało się: $e')),
                  );
                }
              },

              child: const Icon(Icons.playlist_add, size: 28),
            ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.map_outlined),
                tooltip: kIsWeb ? null : 'Opis projektu',
                onPressed: () {
                  Navigator.of(context).push(
                    NoSwipeCupertinoRoute(
                      builder: (_) => ProjectDescriptionScreen(
                        customerId: widget.customerId,
                        projectId: widget.projectId,
                        isAdmin: widget.isAdmin,
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.inventory_outlined),
                tooltip: 'Dokumenty RW',
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RWDocumentsScreen(
                        customerId: widget.customerId,
                        projectId: widget.projectId,
                        isAdmin: widget.isAdmin,
                      ),
                    ),
                  );
                  if (!mounted) return;
                  await _loadAll();
                  await _checkTodayExists('RW');
                  setState(() {});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
