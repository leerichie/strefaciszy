// lib/widgets/project_current_tabs.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProjectCurrentTabs extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> projRef;
  final bool readOnly;
  final String customerId;
  final String projectId;
  final String customerName;
  final String projectName;

  const ProjectCurrentTabs({
    super.key,
    required this.projRef,
    required this.readOnly,
    required this.customerId,
    required this.projectId,
    required this.customerName,
    required this.projectName,
  });

  @override
  State<ProjectCurrentTabs> createState() => _ProjectCurrentTabsState();
}

class _ProjectCurrentTabsState extends State<ProjectCurrentTabs> {
  static const String kInstallerField = 'currentInstaller';
  static const String kCoordinationField = 'currentCoordination';
  static const String kChangesNotesField = 'currentChangesNotes';

  static const String kLegacyCurrentTextField = 'currentText';

  static const String kUpdatedAt = 'updatedAt';
  static const String kUpdatedBy = 'updatedBy';
  static const String kUpdatedByName = 'updatedByName';

  // coord todo
  static const String kShoppingTaskKey = 'shopping';
  static const String kTaskKeyField = 'taskKey';
  static const String kActionField = 'action';
  static const String kShoppingItemIdField = 'shoppingItemId';
  bool _shoppingEnsured = false;

  final Map<String, TextEditingController> _newEntryCtrls = {};
  final Map<String, Timer?> _newEntryDebounce = {};
  final Map<String, ScrollController> _logScrollCtrls = {};

  final Map<String, TextEditingController> _entryCtrls = {};
  final Map<String, Timer?> _entryDebounce = {};
  final Map<String, FocusNode> _entryFocus = {};

  final Map<String, String?> _pendingTaskColorByField = {};
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadIsAdmin();
  }

  @override
  void dispose() {
    for (final t in _newEntryDebounce.values) {
      t?.cancel();
    }
    for (final c in _newEntryCtrls.values) {
      c.dispose();
    }
    for (final s in _logScrollCtrls.values) {
      s.dispose();
    }

    for (final t in _entryDebounce.values) {
      t?.cancel();
    }
    for (final c in _entryCtrls.values) {
      c.dispose();
    }
    for (final f in _entryFocus.values) {
      f.dispose();
    }

    super.dispose();
  }

  Future<void> _ensureLinkedShoppingDoc({
    required Map<String, dynamic> entry,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final entryId = (entry['id'] ?? '').toString();
    if (entryId.isEmpty) return;

    final existingShoppingId = (entry[kShoppingItemIdField] ?? '').toString();
    if (existingShoppingId.isNotEmpty) return;

    final myName = await _resolveUserName(user);

    final shoppingRef = FirebaseFirestore.instance
        .collection('shopping_items')
        .doc();

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final projSnap = await tx.get(widget.projRef);
      if (!projSnap.exists) return;

      final data = projSnap.data() ?? <String, dynamic>{};
      final raw = (data[kCoordinationField] as List?) ?? const [];

      Map<String, dynamic>? found;
      for (final e in raw) {
        if (e is Map && (e['id']?.toString() ?? '') == entryId) {
          found = Map<String, dynamic>.from(e);
          break;
        }
      }
      if (found == null) return;

      final already = (found[kShoppingItemIdField] ?? '').toString();
      if (already.isNotEmpty) return;

      final bool done = (found['done'] == true);

      tx.set(shoppingRef, {
        'text': (found['text'] ?? '').toString(),
        'createdBy': user.uid,
        'createdByName': myName,
        'createdAt': FieldValue.serverTimestamp(),

        'bought': done,
        'boughtAt': done ? FieldValue.serverTimestamp() : null,
        'boughtBy': done ? user.uid : null,
        'boughtByName': done ? myName : null,

        'sourceTaskId': entryId,
        'customerId': widget.customerId,
        'projectId': widget.projectId,
      });

      final updatedEntry = Map<String, dynamic>.from(found);
      updatedEntry[kShoppingItemIdField] = shoppingRef.id;

      final updatedList = raw.map((x) {
        if (x is Map && (x['id']?.toString() ?? '') == entryId) {
          return updatedEntry;
        }
        return x;
      }).toList();

      tx.update(widget.projRef, {
        kCoordinationField: updatedList,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
        'updatedByName': myName,
      });
    });
  }

  Future<void> _onHeaderLongPress({
    required String field,
    required Map<String, dynamic> entry,
  }) async {
    if (widget.readOnly) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final isTask = entry['isTask'] == true;
    final isDone = entry['done'] == true;
    final current = (entry['color'] ?? 'black').toString();

    final picked = await _pickTaskColourOrDeleteDialog(
      isDone: isTask ? isDone : false,
      isAdmin: _isAdmin,
      currentColor: isTask ? current : 'black',
      isTask: isTask,
      allowToText: isTask,
      coordMode: field == kCoordinationField,
    );

    if (picked == null) return;

    if (picked == '__delete__') {
      if (_isAdmin) {
        await _deleteLogEntry(field: field, entry: entry);
      }
      return;
    }

    if (picked == '__to_text__') {
      if (isTask) {
        await _convertTaskToNormalText(field: field, oldEntry: entry);
      }
      return;
    }

    if (picked == 'red' || picked == 'blue' || picked == 'black') {
      if (isTask) {
        if (!isDone && picked != current) {
          await _setTaskColour(field: field, oldEntry: entry, newColor: picked);
        }
      } else {
        if (field == kCoordinationField && picked != 'red') return;

        await _convertNormalTextToTask(
          field: field,
          oldEntry: entry,
          color: picked,
        );
      }
    }
  }

  Future<void> _convertNormalTextToTask({
    required String field,
    required Map<String, dynamic> oldEntry,
    required String color,
  }) async {
    if (widget.readOnly) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (oldEntry['isTask'] == true) return;

    final userName = await _resolveUserName(user);
    final now = Timestamp.now();

    final updated = Map<String, dynamic>.from(oldEntry);
    updated['isTask'] = true;
    updated['done'] = false;
    updated['color'] = color;

    updated[kUpdatedAt] = now;
    updated[kUpdatedBy] = user.uid;
    updated[kUpdatedByName] = userName;

    await widget.projRef.update({
      field: FieldValue.arrayRemove([oldEntry]),
    });
    await widget.projRef.update({
      field: FieldValue.arrayUnion([updated]),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': user.uid,
    });
  }

  Future<void> _convertTaskToNormalText({
    required String field,
    required Map<String, dynamic> oldEntry,
  }) async {
    if (widget.readOnly) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (oldEntry['isTask'] != true) return;

    final userName = await _resolveUserName(user);
    final now = Timestamp.now();

    final updated = Map<String, dynamic>.from(oldEntry);

    updated['isTask'] = false;
    updated.remove('done');
    updated.remove('color');
    updated.remove(kTaskKeyField);
    updated.remove(kShoppingItemIdField);

    updated[kUpdatedAt] = now;
    updated[kUpdatedBy] = user.uid;
    updated[kUpdatedByName] = userName;

    await widget.projRef.update({
      field: FieldValue.arrayRemove([oldEntry]),
    });
    await widget.projRef.update({
      field: FieldValue.arrayUnion([updated]),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': user.uid,
    });
  }

  Future<void> _setTaskColour({
    required String field,
    required Map<String, dynamic> oldEntry,
    required String newColor, // 'red' | 'blue' | 'black'
  }) async {
    if (widget.readOnly) return;

    if (oldEntry['isTask'] != true) return;
    final isShoppingTask =
        (oldEntry[kTaskKeyField]?.toString() ?? '') == kShoppingTaskKey;

    if (field == kCoordinationField && isShoppingTask) {
      final shoppingId = (oldEntry[kShoppingItemIdField] ?? '').toString();
      if (shoppingId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('shopping_items')
            .doc(shoppingId)
            .delete();
      }
    }

    if (oldEntry['done'] == true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userName = await _resolveUserName(user);
    final now = Timestamp.now();

    final updated = Map<String, dynamic>.from(oldEntry);
    updated['color'] = newColor;
    updated[kUpdatedAt] = now;
    updated[kUpdatedBy] = user.uid;
    updated[kUpdatedByName] = userName;

    await widget.projRef.update({
      field: FieldValue.arrayRemove([oldEntry]),
    });
    await widget.projRef.update({
      field: FieldValue.arrayUnion([updated]),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': user.uid,
    });
  }

  Future<void> _removeProjectEntryById({
    required String field,
    required String entryId,
    required User user,
    required String userName,
  }) async {
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(widget.projRef);
      if (!snap.exists) return;

      final data = snap.data() ?? <String, dynamic>{};
      final raw = (data[field] as List?) ?? const [];

      final updated = raw.where((e) {
        if (e is! Map) return true;
        return (e['id']?.toString() ?? '') != entryId;
      }).toList();

      tx.update(widget.projRef, {
        field: updated,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
        'updatedByName': userName,
      });
    });
  }

  Future<bool> _confirmDeleteDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('usuń?'),
        content: const Text('Nieodwracalny...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('USUŃ'),
          ),
        ],
      ),
    );

    return ok == true;
  }

  Future<bool> _confirmMarkDoneDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wykonane?'),
        content: const Text(
          'Zadanie zostanie wpisany do raportu i nie będzie widoczny tu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    return ok == true;
  }

  Future<void> _deleteLogEntry({
    required String field,
    required Map<String, dynamic> entry,
  }) async {
    if (widget.readOnly) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (!_isAdmin) return;
    final ok = await _confirmDeleteDialog();
    if (!ok) return;

    final entryId = (entry['id'] ?? '').toString();
    if (entryId.isEmpty) return;

    final userName = await _resolveUserName(user);

    final isTask = entry['isTask'] == true;
    final isShoppingTask =
        (entry[kTaskKeyField]?.toString() ?? '') == kShoppingTaskKey;

    await _removeProjectEntryById(
      field: field,
      entryId: entryId,
      user: user,
      userName: userName,
    );

    if (field == kCoordinationField && isShoppingTask) {
      final shoppingId = (entry[kShoppingItemIdField] ?? '').toString();
      if (shoppingId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('shopping_items')
            .doc(shoppingId)
            .delete();
      }
    }

    if (isTask && (field == kChangesNotesField || isShoppingTask)) {
      await _removeTaskFromTodayRw(
        user: user,
        userName: userName,
        sourceTaskId: entryId,
      );
    }
  }

  Future<void> _loadIsAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    bool isAdmin = false;

    try {
      final token = await user.getIdTokenResult(true);
      final claimAdmin = token.claims?['admin'];
      if (claimAdmin == true) {
        isAdmin = true;
      }
    } catch (_) {}

    if (!isAdmin) {
      try {
        final u = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (u.data()?['isAdmin'] == true) {
          isAdmin = true;
        }
      } catch (_) {}
    }

    if (mounted) setState(() => _isAdmin = isAdmin);
  }

  String _fmt(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Future<String> _resolveUserName(User user) async {
    final display = (user.displayName ?? '').trim();
    if (display.isNotEmpty) return display;

    final u = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final name = (u.data()?['name'] as String?)?.trim() ?? '';
    if (name.isNotEmpty) return name;

    return (user.email ?? '—');
  }

  Future<String?> _pickCoordinationTaskDialog() async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wybierz typ zadanie:'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              dense: true,
              leading: const Icon(Icons.circle, color: Colors.red),
              title: const Text(
                'Do zakupy',
                style: TextStyle(fontSize: 20, color: Colors.red),
              ),
              onTap: () => Navigator.pop(ctx, 'red'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Anuluj'),
          ),
        ],
      ),
    );
  }

  Future<String?> _pickTaskColourOrDeleteDialog({
    required bool isDone,
    required bool isAdmin,
    required String currentColor,
    required bool isTask,
    required bool allowToText,
    required bool coordMode,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isDone ? 'TODO już wykonane (zablokowany).' : 'Zmienić typ TODO?',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            // --- colours (disabled if done)
            Opacity(
              opacity: isDone ? 0.45 : 1.0,
              child: IgnorePointer(
                ignoring: isDone,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // COORDINATION: only Zakupy (red)
                    if (coordMode)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.circle, color: Colors.red),
                        title: const Text(
                          'Do zakupy',
                          style: TextStyle(fontSize: 15, color: Colors.red),
                        ),
                        trailing: (currentColor == 'red' && isTask)
                            ? const Icon(Icons.check, size: 18)
                            : null,
                        onTap: () => Navigator.pop(ctx, 'red'),
                      )
                    else ...[
                      // TODO TAB: full 3 priorities
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.circle, color: Colors.red),
                        title: const Text(
                          'Pilny!!',
                          style: TextStyle(fontSize: 15, color: Colors.red),
                        ),
                        trailing: currentColor == 'red'
                            ? const Icon(Icons.check, size: 18)
                            : null,
                        onTap: () => Navigator.pop(ctx, 'red'),
                      ),
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.circle, color: Colors.blue),
                        title: const Text(
                          'Dodatkowe prace',
                          style: TextStyle(fontSize: 15, color: Colors.blue),
                        ),
                        trailing: currentColor == 'blue'
                            ? const Icon(Icons.check, size: 18)
                            : null,
                        onTap: () => Navigator.pop(ctx, 'blue'),
                      ),
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.circle, color: Colors.black),
                        title: const Text(
                          'Normalny',
                          style: TextStyle(fontSize: 15),
                        ),
                        trailing: currentColor == 'black'
                            ? const Icon(Icons.check, size: 18)
                            : null,
                        onTap: () => Navigator.pop(ctx, 'black'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (allowToText) ...[
              const Divider(),
              ListTile(
                dense: true,
                leading: const Icon(Icons.text_fields, color: Colors.black87),
                title: const Text(
                  'Zwykly tekst',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                onTap: () => Navigator.pop(ctx, '__to_text__'),
              ),
            ],
            const Divider(),

            // --- admin delete section
            if (isAdmin) ...[
              Divider(color: Colors.grey.shade300),
              const SizedBox(height: 2),
              const Text(
                'Admin:',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Usuń zadanie TODO',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                onTap: () => Navigator.pop(ctx, '__delete__'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Anuluj'),
          ),
        ],
      ),
    );
  }

  Future<String?> _pickTaskColourDialog() async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wybierz typ zadanie:'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              dense: true,
              leading: const Icon(Icons.circle, color: Colors.red),
              title: const Text(
                'Pilny!!',
                style: TextStyle(fontSize: 20, color: Colors.red),
              ),
              onTap: () => Navigator.pop(ctx, 'red'),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.circle, color: Colors.blue),
              title: const Text(
                'Dodatkowe prace',
                style: TextStyle(fontSize: 20, color: Colors.blue),
              ),
              onTap: () => Navigator.pop(ctx, 'blue'),
            ),

            ListTile(
              dense: true,
              leading: const Icon(Icons.circle, color: Colors.black),
              title: const Text('Normalny', style: TextStyle(fontSize: 20)),
              onTap: () => Navigator.pop(ctx, 'black'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Anuluj'),
          ),
        ],
      ),
    );
  }

  Future<void> _createLogEntry({
    required String field,
    required String text,
  }) async {
    if (widget.readOnly) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final userName = await _resolveUserName(user);
    final id = widget.projRef.collection('_tmp').doc().id;
    final now = Timestamp.now();

    final taskColor = _pendingTaskColorByField[field];
    final isTask =
        (taskColor != null) &&
        (field == kChangesNotesField || field == kCoordinationField);

    final entry = <String, dynamic>{
      'id': id,
      'text': trimmed,
      'createdAt': now,
      'createdBy': user.uid,
      'createdByName': userName,
      if (isTask) ...{
        'isTask': true,
        'done': false,
        'color': taskColor,
        if (field == kCoordinationField) kTaskKeyField: kShoppingTaskKey,
      },
    };

    await widget.projRef.update({
      field: FieldValue.arrayUnion([entry]),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': user.uid,
    });
    if (isTask && field == kCoordinationField) {
      await _ensureLinkedShoppingDoc(entry: {'id': id});
    }

    _newEntryCtrls[field]?.clear();
    if (isTask) _pendingTaskColorByField[field] = null;

    final sc = _logScrollCtrls[field];
    if (sc != null && sc.hasClients) {
      sc.animateTo(
        0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _ensureShoppingTaskExists(
    Map<String, dynamic> projectData,
  ) async {
    if (_shoppingEnsured) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (widget.readOnly) return;

    final raw = (projectData[kCoordinationField] as List?) ?? const [];
    final exists = raw.any((e) {
      if (e is! Map) return false;
      return (e[kTaskKeyField]?.toString() ?? '') == kShoppingTaskKey;
    });

    if (exists) {
      _shoppingEnsured = true;

      await _ensureLinkedShoppingDoc(entry: {'id': kShoppingTaskKey});
      return;
    }

    _shoppingEnsured = true; // prevent multiple

    final userName = await _resolveUserName(user);
    final entry = <String, dynamic>{
      'id': kShoppingTaskKey,
      kTaskKeyField: kShoppingTaskKey,
      'text': 'Do zakupy',
      'createdAt': Timestamp.now(),
      'createdBy': user.uid,
      'createdByName': userName,
      'isTask': true,
      'done': false,
      'color': 'red',
    };

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(widget.projRef);
      if (!snap.exists) return;

      final data = snap.data() ?? <String, dynamic>{};
      final list = (data[kCoordinationField] as List?) ?? const [];

      final stillMissing = !list.any((e) {
        if (e is! Map) return false;
        return (e[kTaskKeyField]?.toString() ?? '') == kShoppingTaskKey;
      });
      if (!stillMissing) return;

      tx.update(widget.projRef, {
        kCoordinationField: FieldValue.arrayUnion([entry]),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
        'updatedByName': userName,
      });
      await _ensureLinkedShoppingDoc(entry: {'id': kShoppingTaskKey});
    });
  }

  Future<void> _updateLogEntry({
    required String field,
    required Map<String, dynamic> oldEntry,
    required String newText,
  }) async {
    if (widget.readOnly) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final trimmed = newText.trim();
    if (trimmed.isEmpty) return;

    final userName = await _resolveUserName(user);
    final now = Timestamp.now();

    final updated = Map<String, dynamic>.from(oldEntry);
    updated['text'] = trimmed;
    updated[kUpdatedAt] = now;
    updated[kUpdatedBy] = user.uid;
    updated[kUpdatedByName] = userName;

    await widget.projRef.update({
      field: FieldValue.arrayRemove([oldEntry]),
    });
    await widget.projRef.update({
      field: FieldValue.arrayUnion([updated]),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': user.uid,
    });
    final isShoppingTask =
        (oldEntry[kTaskKeyField]?.toString() ?? '') == kShoppingTaskKey;

    if (field == kCoordinationField && isShoppingTask) {
      await _ensureLinkedShoppingDoc(
        entry: {'id': (oldEntry['id'] ?? '').toString()},
      );

      final snap = await widget.projRef.get();
      final data = snap.data() ?? <String, dynamic>{};
      final list = (data[kCoordinationField] as List?) ?? const [];

      final found = list.cast<dynamic>().firstWhere(
        (e) =>
            e is Map &&
            (e['id']?.toString() ?? '') == (oldEntry['id'] ?? '').toString(),
        orElse: () => null,
      );

      if (found is Map) {
        final shoppingId = (found[kShoppingItemIdField] ?? '').toString();
        if (shoppingId.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('shopping_items')
              .doc(shoppingId)
              .update({'text': trimmed});
        }
      }
    }
  }

  Future<DocumentReference<Map<String, dynamic>>?> _todayRwRef() async {
    final proj = FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId);

    final now = DateTime.now().toLocal();
    final day = DateTime(now.year, now.month, now.day);

    final snap = await proj
        .collection('rw_documents')
        .where('type', isEqualTo: 'RW')
        .where('createdDay', isEqualTo: day)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return snap.docs.first.reference;
  }

  Future<void> _removeTaskFromTodayRw({
    required User user,
    required String userName,
    required String sourceTaskId,
  }) async {
    final existingRwRef = await _todayRwRef();
    if (existingRwRef == null) return;

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(existingRwRef);
      if (!snap.exists) return;

      final data = snap.data() ?? <String, dynamic>{};
      final raw = (data['notesList'] as List?) ?? const [];

      final updated = raw.where((e) {
        if (e is! Map) return true;
        final sid = (e['sourceTaskId'] ?? '').toString();
        return sid != sourceTaskId;
      }).toList();

      tx.update(existingRwRef, {
        'notesList': updated,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
        'lastUpdatedBy': user.uid,
        'lastUpdatedByName': userName,
      });
    });
  }

  Future<void> _appendTaskDoneToTodayRw({
    required User user,
    required String userName,
    required Map<String, dynamic> taskEntry,
    required String action,
  }) async {
    if (taskEntry['isTask'] != true) return;

    final text = (taskEntry['text'] ?? '').toString().trim();
    if (text.isEmpty) return;

    final sourceTaskId = (taskEntry['id'] ?? '').toString();
    if (sourceTaskId.isEmpty) return;

    final proj = FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects')
        .doc(widget.projectId);

    final noteMap = <String, dynamic>{
      'text': text,
      'userName': userName,
      'createdAt': Timestamp.now(),
      'action': action,
      if (taskEntry['color'] != null) 'color': taskEntry['color'],
      'sourceTaskId': sourceTaskId,
    };

    final existingRwRef = await _todayRwRef();

    if (existingRwRef != null) {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(existingRwRef);
        if (!snap.exists) return;

        final data = snap.data() ?? <String, dynamic>{};
        final raw = (data['notesList'] as List?) ?? const [];

        final filtered = raw.where((e) {
          if (e is! Map) return true;
          return (e['sourceTaskId']?.toString() ?? '') != sourceTaskId;
        }).toList();

        filtered.add(noteMap);

        tx.update(existingRwRef, {
          'notesList': filtered,
          'lastUpdatedAt': FieldValue.serverTimestamp(),
          'lastUpdatedBy': user.uid,
          'lastUpdatedByName': userName,
        });
      });

      return;
    }

    final now = DateTime.now();
    final newRwRef = proj.collection('rw_documents').doc();

    await newRwRef.set({
      'type': 'RW',
      'customerId': widget.customerId,
      'projectId': widget.projectId,
      'customerName': widget.customerName,
      'projectName': widget.projectName,
      'createdDay': DateTime(now.year, now.month, now.day),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': user.uid,
      'createdByName': userName,
      'items': <Map<String, dynamic>>[],
      'notesList': [noteMap],
    });
  }

  Future<void> _toggleLogTaskDone({
    required String field,
    required Map<String, dynamic> oldEntry,
    required bool done,
  }) async {
    if (widget.readOnly) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // if (!_canEditEntryWithAdmin(oldEntry, user)) return;

    final wasDone = oldEntry['done'] == true;
    final isTask = oldEntry['isTask'] == true;

    final shouldCopyToRw =
        isTask &&
        done == true &&
        !wasDone &&
        (field == kChangesNotesField || field == kCoordinationField);

    final shouldRemoveFromRw =
        isTask &&
        done == false &&
        wasDone &&
        (field == kChangesNotesField || field == kCoordinationField);

    final userName = await _resolveUserName(user);
    final now = Timestamp.now();

    final updated = Map<String, dynamic>.from(oldEntry);
    updated['done'] = done;
    updated[kUpdatedAt] = now;
    updated[kUpdatedBy] = user.uid;
    updated[kUpdatedByName] = userName;

    await widget.projRef.update({
      field: FieldValue.arrayRemove([oldEntry]),
    });
    await widget.projRef.update({
      field: FieldValue.arrayUnion([updated]),
    });

    final isShoppingTask =
        (oldEntry[kTaskKeyField]?.toString() ?? '') == kShoppingTaskKey;

    if (field == kCoordinationField && isShoppingTask) {
      await _ensureLinkedShoppingDoc(
        entry: {'id': (oldEntry['id'] ?? '').toString()},
      );

      final snap = await widget.projRef.get();
      final data = snap.data() ?? <String, dynamic>{};
      final list = (data[kCoordinationField] as List?) ?? const [];

      final found = list.cast<dynamic>().firstWhere(
        (e) =>
            e is Map &&
            (e['id']?.toString() ?? '') == (oldEntry['id'] ?? '').toString(),
        orElse: () => null,
      );

      if (found is Map) {
        final shoppingId = (found[kShoppingItemIdField] ?? '').toString();
        if (shoppingId.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('shopping_items')
              .doc(shoppingId)
              .update({
                'bought': done,
                'boughtAt': done ? FieldValue.serverTimestamp() : null,
                'boughtBy': done ? user.uid : null,
                'boughtByName': done ? userName : null,
              });
        }
      }
    }

    if (shouldCopyToRw) {
      final action = (field == kCoordinationField) ? 'ZAKUPY' : 'TODO';
      await _appendTaskDoneToTodayRw(
        user: user,
        userName: userName,
        taskEntry: updated,
        action: action,
      );
    }

    if (shouldRemoveFromRw) {
      final sourceTaskId = (oldEntry['id'] ?? '').toString();
      if (sourceTaskId.isNotEmpty) {
        await _removeTaskFromTodayRw(
          user: user,
          userName: userName,
          sourceTaskId: sourceTaskId,
        );
      }
    }
  }

  // Future<void> _addShoppingTask({required String text}) async {
  //   if (widget.readOnly) return;

  //   final user = FirebaseAuth.instance.currentUser;
  //   if (user == null) return;

  //   final trimmed = text.trim();
  //   final finalText = trimmed.isEmpty ? 'Do zakupy' : trimmed;

  //   final userName = await _resolveUserName(user);

  //   final entry = <String, dynamic>{
  //     'id': kShoppingTaskKey,
  //     kTaskKeyField: kShoppingTaskKey,
  //     'text': finalText,
  //     'createdAt': Timestamp.now(),
  //     'createdBy': user.uid,
  //     'createdByName': userName,
  //     'isTask': true,
  //     'done': false,
  //     'color': 'red',
  //   };

  //   await FirebaseFirestore.instance.runTransaction((tx) async {
  //     final snap = await tx.get(widget.projRef);
  //     if (!snap.exists) return;

  //     final data = snap.data() ?? <String, dynamic>{};
  //     final list = (data[kCoordinationField] as List?) ?? const [];

  //     final existing = list.cast<dynamic>().firstWhere(
  //       (e) =>
  //           e is Map &&
  //           (e[kTaskKeyField]?.toString() ?? '') == kShoppingTaskKey,
  //       orElse: () => null,
  //     );

  //     if (existing != null && existing is Map) {
  //       final existingMap = Map<String, dynamic>.from(existing);
  //       final updated = Map<String, dynamic>.from(existingMap);
  //       updated['text'] = finalText;
  //       updated[kUpdatedAt] = Timestamp.now();
  //       updated[kUpdatedBy] = user.uid;
  //       updated[kUpdatedByName] = userName;

  //       tx.update(widget.projRef, {
  //         kCoordinationField: FieldValue.arrayRemove([existingMap]),
  //       });
  //       tx.update(widget.projRef, {
  //         kCoordinationField: FieldValue.arrayUnion([updated]),
  //         'updatedAt': FieldValue.serverTimestamp(),
  //         'updatedBy': user.uid,
  //         'updatedByName': userName,
  //       });
  //       return;
  //     }

  //     tx.update(widget.projRef, {
  //       kCoordinationField: FieldValue.arrayUnion([entry]),
  //       'updatedAt': FieldValue.serverTimestamp(),
  //       'updatedBy': user.uid,
  //       'updatedByName': userName,
  //     });
  //   });
  //   await _ensureLinkedShoppingDoc(entry: {'id': kShoppingTaskKey});
  // }

  List<Map<String, dynamic>> _readEntries(
    Map<String, dynamic> data,
    String field,
  ) {
    final raw = (data[field] as List<dynamic>?) ?? const [];
    final list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    DateTime activityAt(Map<String, dynamic> e) {
      final u = (e[kUpdatedAt] as Timestamp?)?.toDate();
      final c = (e['createdAt'] as Timestamp?)?.toDate();
      return (u ?? c ?? DateTime.fromMillisecondsSinceEpoch(0)).toLocal();
    }

    list.sort((a, b) => activityAt(b).compareTo(activityAt(a)));
    return list;
  }

  Widget _legacyCompactBlock(String legacyText) {
    final t = legacyText.trim();
    if (t.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.shade300, height: 1)),
              const SizedBox(width: 8),
              const Text(
                'Archive (BIEŻĄCE)',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
              const SizedBox(width: 8),
              Expanded(child: Divider(color: Colors.grey.shade300, height: 1)),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(t, style: const TextStyle(fontSize: 12, height: 1.25)),
        ],
      ),
    );
  }

  Widget _compactLogEditor({
    required String field,
    required String hint,
    required List<Map<String, dynamic>> entries,
    Widget? bottom,
  }) {
    final user = FirebaseAuth.instance.currentUser;

    final inputCtrl = _newEntryCtrls.putIfAbsent(
      field,
      () => TextEditingController(),
    );
    final scrollCtrl = _logScrollCtrls.putIfAbsent(
      field,
      () => ScrollController(),
    );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(8),
      child: ListView.builder(
        controller: scrollCtrl,
        padding: EdgeInsets.zero,
        itemCount: 1 + entries.length + (bottom != null ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == 0) {
            final armed = _pendingTaskColorByField[field];
            final iconColor = armed == 'red'
                ? Colors.red
                : armed == 'blue'
                ? Colors.blue
                : armed == 'black'
                ? Colors.black
                : Colors.black54;

            return Column(
              children: [
                TextField(
                  controller: inputCtrl,
                  enabled: !widget.readOnly,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    isDense: true,
                    border: const OutlineInputBorder(),
                    hintText: hint,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    suffixIcon: (field == kChangesNotesField)
                        ? IconButton(
                            tooltip: 'Wpis checkbox',
                            icon: Icon(
                              Icons.check_box,
                              color: iconColor,
                              fontWeight: FontWeight.w800,
                              size: 25,
                            ),
                            onPressed: widget.readOnly
                                ? null
                                : () async {
                                    final picked =
                                        await _pickTaskColourDialog();
                                    if (picked == null) return;

                                    setState(
                                      () => _pendingTaskColorByField[field] =
                                          picked,
                                    );
                                  },
                          )
                        : (field == kCoordinationField)
                        ? IconButton(
                            tooltip: 'Wpis checkbox',
                            icon: const Icon(
                              Icons.check_box,
                              color: Colors.red,
                              size: 25,
                            ),
                            onPressed: widget.readOnly
                                ? null
                                : () async {
                                    final picked =
                                        await _pickCoordinationTaskDialog();
                                    if (picked == null) return;

                                    setState(
                                      () => _pendingTaskColorByField[field] =
                                          picked,
                                    );

                                    final typed = inputCtrl.text.trim();
                                    await _createLogEntry(
                                      field: field,
                                      text: typed.isEmpty ? 'Do zakupy' : typed,
                                    );
                                  },
                          )
                        : null,
                  ),
                  onSubmitted: (v) => _createLogEntry(field: field, text: v),
                ),

                const SizedBox(height: 8),
              ],
            );
          }

          final entryIndex = index - 1;

          // LEGACY
          if (bottom != null && entryIndex == entries.length) {
            return bottom;
          }

          final e = entries[entryIndex];
          final id = (e['id'] as String?) ?? '';
          final text = (e['text'] as String?) ?? '';

          final createdAt = (e['createdAt'] as Timestamp?)?.toDate().toLocal();
          final createdByName = (e['createdByName'] as String?) ?? '';

          final updatedAt = (e[kUpdatedAt] as Timestamp?)?.toDate().toLocal();
          final updatedByName = (e[kUpdatedByName] as String?) ?? '';

          final canEdit = user != null;
          final canDelete = _isAdmin && user != null;
          final headerTime = updatedAt ?? createdAt;
          final headerName = (updatedAt != null ? updatedByName : createdByName)
              .trim();

          final header = headerTime == null
              ? '—'
              : '${_fmt(headerTime)}'
                    '${headerName.isNotEmpty ? ' • $headerName' : ''}'
                    '${updatedAt != null ? ' (edyt.)' : ''}';

          final ctrl = _entryCtrls.putIfAbsent(
            id,
            () => TextEditingController(),
          );
          final focus = _entryFocus.putIfAbsent(id, () => FocusNode());

          if (!focus.hasFocus && ctrl.text != text) {
            ctrl.text = text;
          }

          final isTask = e['isTask'] == true;
          final done = e['done'] == true;
          final colorStr = (e['color'] ?? 'black').toString();
          final taskColor = colorStr == 'red'
              ? Colors.red
              : colorStr == 'blue'
              ? Colors.blue
              : Colors.black;

          return Padding(
            padding: EdgeInsets.only(
              bottom: entryIndex == entries.length - 1 ? 0 : 10,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER
                InkWell(
                  onLongPress: (user != null && !widget.readOnly)
                      ? () => _onHeaderLongPress(field: field, entry: e)
                      : null,
                  child: Text(
                    header,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black54,
                      height: 1.1,
                    ),
                  ),
                ),

                const SizedBox(height: 3),

                // BODY
                if (isTask)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 20,
                        width: 20,
                        child: Checkbox(
                          value: done,
                          onChanged: (canEdit && !widget.readOnly)
                              ? (v) async {
                                  final nextDone = (v == true);

                                  if (nextDone) {
                                    final ok = await _confirmMarkDoneDialog();
                                    if (!ok) return;
                                  }

                                  await _toggleLogTaskDone(
                                    field: field,
                                    oldEntry: e,
                                    done: nextDone,
                                  );
                                }
                              : null,
                          activeColor: Colors.green,
                          checkColor: Colors.white,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: const VisualDensity(
                            horizontal: -4,
                            vertical: -4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: (canEdit && !widget.readOnly)
                            ? TextField(
                                controller: ctrl,
                                focusNode: focus,
                                minLines: 1,
                                maxLines: null,
                                textInputAction: TextInputAction.done,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.2,
                                  color: taskColor,
                                ),
                                onSubmitted: (v) => _updateLogEntry(
                                  field: field,
                                  oldEntry: e,
                                  newText: v,
                                ),
                              )
                            : SelectableText(
                                text,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.2,
                                  color: taskColor,
                                ),
                              ),
                      ),
                    ],
                  )
                else
                  (canEdit && !widget.readOnly)
                      ? TextField(
                          controller: ctrl,
                          focusNode: focus,
                          minLines: 1,
                          maxLines: null,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(fontSize: 13, height: 1.2),
                          onSubmitted: (v) => _updateLogEntry(
                            field: field,
                            oldEntry: e,
                            newText: v,
                          ),
                        )
                      : SelectableText(
                          text,
                          style: const TextStyle(fontSize: 13, height: 1.2),
                        ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: const TabBar(
              labelColor: Color.fromARGB(255, 47, 101, 182),
              unselectedLabelColor: Colors.black54,

              tabs: [
                Tab(text: 'INSTALATOR'),
                Tab(text: 'KOORDYNACJA'),
                Tab(text: 'TODO'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 320,
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: widget.projRef.snapshots(),
              builder: (context, snap) {
                if (!snap.hasData || !snap.data!.exists) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snap.data!.data() ?? <String, dynamic>{};

                final legacyCurrentText =
                    (data[kLegacyCurrentTextField] as String?)?.trim() ?? '';

                final installer = _readEntries(data, kInstallerField);
                final coordinationAll = _readEntries(data, kCoordinationField);

                final coordination = coordinationAll.where((e) {
                  final isTask = e['isTask'] == true;
                  final done = e['done'] == true;
                  if (isTask && done) return false;
                  return true;
                }).toList();
                final changesNotesAll = _readEntries(data, kChangesNotesField);

                final changesNotes = changesNotesAll.where((e) {
                  final isTask = e['isTask'] == true;
                  final done = e['done'] == true;

                  if (isTask && done) return false;
                  return true;
                }).toList();
                return TabBarView(
                  children: [
                    _compactLogEditor(
                      field: kInstallerField,
                      hint: 'Wpisz do instalatora...',
                      entries: installer,
                    ),
                    _compactLogEditor(
                      field: kCoordinationField,
                      hint: 'Wpisz do koordynacja...',
                      entries: coordination,
                    ),
                    _compactLogEditor(
                      field: kChangesNotesField,
                      hint: 'Wpisz zadanie TODO',
                      entries: changesNotes,
                      bottom: _legacyCompactBlock(legacyCurrentText),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
