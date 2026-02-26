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

  // Future<void> _setTaskColour({
  //   required String field,
  //   required Map<String, dynamic> oldEntry,
  //   required String color, // 'red' | 'blue' | 'black'
  // }) async {
  //   if (widget.readOnly) return;

  //   final user = FirebaseAuth.instance.currentUser;
  //   if (user == null) return;

  //   if (oldEntry['done'] == true) return;
  //   final userName = await _resolveUserName(user);
  //   final now = Timestamp.now();

  //   final updated = Map<String, dynamic>.from(oldEntry);
  //   updated['color'] = color;
  //   updated[kUpdatedAt] = now;
  //   updated[kUpdatedBy] = user.uid;
  //   updated[kUpdatedByName] = userName;

  //   await widget.projRef.update({
  //     field: FieldValue.arrayRemove([oldEntry]),
  //   });
  //   await widget.projRef.update({
  //     field: FieldValue.arrayUnion([updated]),
  //     'updatedAt': FieldValue.serverTimestamp(),
  //     'updatedBy': user.uid,
  //   });

  //   final isDone = oldEntry['done'] == true;
  //   if (field == kChangesNotesField && isDone) {
  //     final sourceTaskId = (oldEntry['id'] ?? '').toString();
  //     if (sourceTaskId.isNotEmpty) {
  //       await _updateTaskColourInTodayRw(
  //         user: user,
  //         userName: userName,
  //         sourceTaskId: sourceTaskId,
  //         color: color,
  //       );
  //     }
  //   }
  // }

  Future<void> _onHeaderLongPress({
    required String field,
    required Map<String, dynamic> entry,
  }) async {
    if (widget.readOnly) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final isTask = entry['isTask'] == true;

    if (!isTask) {
      if (_isAdmin) {
        await _deleteLogEntry(field: field, entry: entry);
      }
      return;
    }
    final isShoppingTask =
        (entry[kTaskKeyField]?.toString() ?? '') == kShoppingTaskKey;

    if (isShoppingTask) {
      // Only admin delete allowed from this dialog; no colour changes.
      if (_isAdmin) {
        final ok = await _confirmDeleteDialog();
        if (!ok) return;
        await _deleteLogEntry(field: field, entry: entry);
      }
      return;
    }
    final isDone = entry['done'] == true;
    final current = (entry['color'] ?? 'black').toString();

    final picked = await _pickTaskColourOrDeleteDialog(
      isDone: isDone,
      isAdmin: _isAdmin,
      currentColor: current,
    );

    if (picked == null) return;

    if (picked == '__delete__') {
      if (_isAdmin) {
        await _deleteLogEntry(field: field, entry: entry);
      }
      return;
    }

    if (!isDone && picked != current) {
      await _setTaskColour(field: field, oldEntry: entry, newColor: picked);
    }
  }

  Future<void> _setTaskColour({
    required String field,
    required Map<String, dynamic> oldEntry,
    required String newColor, // 'red' | 'blue' | 'black'
  }) async {
    if (widget.readOnly) return;

    // Only for checkbox tasks
    if (oldEntry['isTask'] != true) return;

    // Don’t allow changing colour after done (your requirement)
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

  // Future<void> _updateTaskColourInTodayRw({
  //   required User user,
  //   required String userName,
  //   required String sourceTaskId,
  //   required String color,
  // }) async {
  //   final rwRef = await _todayRwRef();
  //   if (rwRef == null) return;

  //   await FirebaseFirestore.instance.runTransaction((tx) async {
  //     final snap = await tx.get(rwRef);
  //     if (!snap.exists) return;

  //     final data = snap.data() ?? <String, dynamic>{};
  //     final raw = (data['notesList'] as List?) ?? const [];

  //     bool changed = false;

  //     final updatedNotes = raw.map((e) {
  //       if (e is! Map) return e;
  //       final sid = (e['sourceTaskId'] ?? '').toString();
  //       if (sid != sourceTaskId) return e;

  //       final m = Map<String, dynamic>.from(e);
  //       m['color'] = color;
  //       changed = true;
  //       return m;
  //     }).toList();

  //     if (!changed) return;

  //     tx.update(rwRef, {
  //       'notesList': updatedNotes,
  //       'lastUpdatedAt': FieldValue.serverTimestamp(),
  //       'lastUpdatedBy': user.uid,
  //       'lastUpdatedByName': userName,
  //     });
  //   });
  // }

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

  Future<bool> _confirmAddShoppingTaskDialog({
    required String previewText,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zakupy'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dodać "Do zakupy" jako TODO?'),
            const SizedBox(height: 12),
            const Text(
              'Treść:',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              previewText.isEmpty ? 'Do zakupy' : previewText,
              style: const TextStyle(color: Colors.red, fontSize: 15),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Dodaj'),
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

    await _removeProjectEntryById(
      field: field,
      entryId: entryId,
      user: user,
      userName: userName,
    );

    final isTask = entry['isTask'] == true;
    final isShoppingTask =
        (entry[kTaskKeyField]?.toString() ?? '') == kShoppingTaskKey;

    if (isTask && (field == kChangesNotesField || isShoppingTask)) {
      await _removeTaskFromTodayRw(
        user: user,
        userName: userName,
        sourceTaskId: entryId,
      );
    }
  }

  // Future<void> _loadIsAdmin() async {
  //   final user = FirebaseAuth.instance.currentUser;
  //   if (user == null) return;

  //   try {
  //     final u = await FirebaseFirestore.instance
  //         .collection('users')
  //         .doc(user.uid)
  //         .get();
  //     final v = u.data()?['isAdmin'];
  //     final isAdmin = v == true;

  //     if (mounted) {
  //       setState(() => _isAdmin = isAdmin);
  //     }
  //   } catch (_) {
  //   }
  // }
  Future<void> _loadIsAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    bool isAdmin = false;

    // 1) Prefer custom claims: request.auth.token.admin
    try {
      final token = await user.getIdTokenResult(true);
      final claimAdmin = token.claims?['admin'];
      if (claimAdmin == true) {
        isAdmin = true;
      }
    } catch (_) {
      // ignore
    }

    // 2) Fallback to users/{uid}.isAdmin (optional)
    if (!isAdmin) {
      try {
        final u = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (u.data()?['isAdmin'] == true) {
          isAdmin = true;
        }
      } catch (_) {
        // ignore
      }
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

  // bool _canEditEntryWithAdmin(Map<String, dynamic> e, User user) {
  //   if (_isAdmin) return true;

  //   final createdBy = (e['createdBy'] as String?) ?? '';
  //   if (createdBy != user.uid) return false;

  //   final createdAt = (e['createdAt'] as Timestamp?)?.toDate();
  //   if (createdAt == null) return false;

  //   final c = createdAt.toLocal();
  //   final now = DateTime.now().toLocal();

  //   return c.year == now.year && c.month == now.month && c.day == now.day;
  // }

  Future<String?> _pickTaskColourOrDeleteDialog({
    required bool isDone,
    required bool isAdmin,
    required String currentColor, // 'red' | 'blue' | 'black'
  }) async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        // title: const Text('Wybierz typ zadanie:'),
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
                ),
              ),
            ),
            Divider(),

            // --- admin delete section
            if (isAdmin) ...[
              // const SizedBox(height: 12),
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
    final isTask = (field == kChangesNotesField) && (taskColor != null);

    final entry = <String, dynamic>{
      'id': id,
      'text': trimmed,
      'createdAt': now,
      'createdBy': user.uid,
      'createdByName': userName,
      if (isTask) ...{
        'isTask': true,
        'done': false,
        'color': taskColor, // 'red' | 'black'
      },
    };

    await widget.projRef.update({
      field: FieldValue.arrayUnion([entry]),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': user.uid,
    });

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

    // If already exists in snapshot, just mark ensured and exit.
    final raw = (projectData[kCoordinationField] as List?) ?? const [];
    final exists = raw.any((e) {
      if (e is! Map) return false;
      return (e[kTaskKeyField]?.toString() ?? '') == kShoppingTaskKey;
    });

    if (exists) {
      _shoppingEnsured = true;
      return;
    }

    _shoppingEnsured = true; // prevent multiple calls while transaction runs

    final userName = await _resolveUserName(user);
    final entry = <String, dynamic>{
      'id': kShoppingTaskKey, // fixed id so we can reliably find it
      kTaskKeyField: kShoppingTaskKey, // fixed “kind”
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

    // if (!_canEditEntryWithAdmin(oldEntry, user)) return;

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
  }

  // Future<DocumentReference<Map<String, dynamic>>?> _todayRwRef() async {
  //   final proj = FirebaseFirestore.instance
  //       .collection('customers')
  //       .doc(widget.customerId)
  //       .collection('projects')
  //       .doc(widget.projectId);

  //   final now = DateTime.now().toLocal();
  //   final start = DateTime(now.year, now.month, now.day);
  //   final end = start.add(const Duration(days: 1));

  //   final snap = await proj
  //       .collection('rw_documents')
  //       .where('type', isEqualTo: 'RW')
  //       .where('createdAt', isGreaterThanOrEqualTo: start)
  //       .where('createdAt', isLessThan: end)
  //       .orderBy('createdAt', descending: true)
  //       .limit(1)
  //       .get();

  //   if (snap.docs.isEmpty) return null;
  //   return snap.docs.first.reference;
  // }

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

    final isShoppingTask =
        (oldEntry[kTaskKeyField]?.toString() ?? '') == kShoppingTaskKey;

    final shouldCopyToRw =
        isTask &&
        (done == true) &&
        !wasDone &&
        (field == kChangesNotesField || isShoppingTask);

    final shouldRemoveFromRw =
        isTask &&
        (done == false) &&
        wasDone &&
        (field == kChangesNotesField || isShoppingTask);

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

    if (shouldCopyToRw) {
      final action = isShoppingTask ? 'Koordynacja/Zakupy' : 'Raporty/Zmiany';
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

  Future<void> _addShoppingTask({required String text}) async {
    if (widget.readOnly) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final trimmed = text.trim();
    final finalText = trimmed.isEmpty ? 'Do zakupy' : trimmed;

    final userName = await _resolveUserName(user);

    final entry = <String, dynamic>{
      'id': kShoppingTaskKey, // fixed id
      kTaskKeyField: kShoppingTaskKey,
      'text': finalText,
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

      // If it already exists and NOT done -> update its text (replace the map)
      final existing = list.cast<dynamic>().firstWhere(
        (e) =>
            e is Map &&
            (e[kTaskKeyField]?.toString() ?? '') == kShoppingTaskKey,
        orElse: () => null,
      );

      if (existing != null && existing is Map) {
        final existingMap = Map<String, dynamic>.from(existing);

        // If it was done, allow re-creating a fresh one (optional).
        // If you want "done stays done forever", then: if (existingMap['done'] == true) return;
        final updated = Map<String, dynamic>.from(existingMap);
        updated['text'] = finalText;
        updated[kUpdatedAt] = Timestamp.now();
        updated[kUpdatedBy] = user.uid;
        updated[kUpdatedByName] = userName;

        tx.update(widget.projRef, {
          kCoordinationField: FieldValue.arrayRemove([existingMap]),
        });
        tx.update(widget.projRef, {
          kCoordinationField: FieldValue.arrayUnion([updated]),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': user.uid,
          'updatedByName': userName,
        });
        return;
      }

      // Otherwise create it
      tx.update(widget.projRef, {
        kCoordinationField: FieldValue.arrayUnion([entry]),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
        'updatedByName': userName,
      });
    });
  }

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
          // INPUT ROW
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
                            tooltip: 'Dodaj: Do zakupy',
                            icon: const Icon(
                              Icons.check_box,
                              color: Colors.red,
                              size: 25,
                            ),
                            onPressed: widget.readOnly
                                ? null
                                : () async {
                                    final typed = inputCtrl.text;
                                    final ok =
                                        await _confirmAddShoppingTaskDialog(
                                          previewText: typed,
                                        );
                                    if (!ok) return;

                                    await _addShoppingTask(text: typed);
                                    inputCtrl.clear();
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
                final coordination = _readEntries(data, kCoordinationField);
                // Ensure the single “Do zakupy” task exists (once) so toggling works reliably.
                // if (!_shoppingEnsured) {
                //   // fire-and-forget, but only once
                //   _ensureShoppingTaskExists(data);
                // }
                // Pull out the special shopping task so it doesn’t mix with normal notes.
                Map<String, dynamic>? shopping;
                final coordinationRest = <Map<String, dynamic>>[];

                for (final e in coordination) {
                  final isShoppingTask =
                      (e[kTaskKeyField]?.toString() ?? '') == kShoppingTaskKey;
                  if (isShoppingTask) {
                    shopping = e;
                  } else {
                    coordinationRest.add(e);
                  }
                }

                // Hide it in UI when done
                final shoppingDone = shopping?['done'] == true;
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
                      entries: [
                        if (shopping != null && !shoppingDone) shopping,
                        ...coordinationRest,
                      ],
                    ),
                    _compactLogEditor(
                      field: kChangesNotesField,
                      hint: 'Wpisz raport / Dodać Zadanie',
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
