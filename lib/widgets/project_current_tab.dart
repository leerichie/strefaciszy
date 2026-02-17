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

  Future<bool> _confirmDeleteDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete entry?'),
        content: const Text('This will permanently delete this entry.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
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

    if (!_canEditEntryWithAdmin(entry, user)) return;

    final ok = await _confirmDeleteDialog();
    if (!ok) return;

    await widget.projRef.update({
      field: FieldValue.arrayRemove([entry]),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': user.uid,
    });
  }

  Future<void> _loadIsAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final u = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final v = u.data()?['isAdmin'];
      final isAdmin = v == true;

      if (mounted) {
        setState(() => _isAdmin = isAdmin);
      }
    } catch (_) {
      // keep false
    }
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

  bool _canEditEntryWithAdmin(Map<String, dynamic> e, User user) {
    if (_isAdmin) return true;

    final createdBy = (e['createdBy'] as String?) ?? '';
    if (createdBy != user.uid) return false;

    final createdAt = (e['createdAt'] as Timestamp?)?.toDate();
    if (createdAt == null) return false;

    final c = createdAt.toLocal();
    final now = DateTime.now().toLocal();

    return c.year == now.year && c.month == now.month && c.day == now.day;
  }

  Future<String?> _pickTaskColourDialog() async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nowy wpis checkbox'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              dense: true,
              leading: const Icon(Icons.flag, color: Colors.red),
              title: const Text('PILNY – czerwony'),
              onTap: () => Navigator.pop(ctx, 'red'),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.flag, color: Colors.black),
              title: const Text('Normalne – czarny'),
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

  Future<void> _updateLogEntry({
    required String field,
    required Map<String, dynamic> oldEntry,
    required String newText,
  }) async {
    if (widget.readOnly) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (!_canEditEntryWithAdmin(oldEntry, user)) return;

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

  Future<void> _toggleLogTaskDone({
    required String field,
    required Map<String, dynamic> oldEntry,
    required bool done,
  }) async {
    if (widget.readOnly) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (!_canEditEntryWithAdmin(oldEntry, user)) return;

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
                    suffixIcon: field == kChangesNotesField
                        ? IconButton(
                            tooltip: 'Wpis checkbox',
                            icon: Icon(
                              Icons.check_box_outlined,
                              color: iconColor,
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

          final canEdit = user != null && _canEditEntryWithAdmin(e, user);

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
          final taskColor = colorStr == 'red' ? Colors.red : Colors.black;

          return Padding(
            padding: EdgeInsets.only(
              bottom: entryIndex == entries.length - 1 ? 0 : 10,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER
                InkWell(
                  onLongPress: (canEdit && !widget.readOnly)
                      ? () => _deleteLogEntry(field: field, entry: e)
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
                              ? (v) => _toggleLogTaskDone(
                                  field: field,
                                  oldEntry: e,
                                  done: v == true,
                                )
                              : null,
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
                                onChanged: (v) {
                                  _entryDebounce[id]?.cancel();
                                  _entryDebounce[id] = Timer(
                                    const Duration(milliseconds: 700),
                                    () => _updateLogEntry(
                                      field: field,
                                      oldEntry: e,
                                      newText: v,
                                    ),
                                  );
                                },
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
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(fontSize: 13, height: 1.2),
                          onChanged: (v) {
                            _entryDebounce[id]?.cancel();
                            _entryDebounce[id] = Timer(
                              const Duration(milliseconds: 700),
                              () => _updateLogEntry(
                                field: field,
                                oldEntry: e,
                                newText: v,
                              ),
                            );
                          },
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
              labelColor: Colors.black,
              unselectedLabelColor: Colors.black54,
              tabs: [
                Tab(text: 'Instalator'),
                Tab(text: 'Koordynacja'),
                Tab(text: 'Raporty'),
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
                final changesNotes = _readEntries(data, kChangesNotesField);

                return TabBarView(
                  children: [
                    _compactLogEditor(
                      field: kInstallerField,
                      hint: 'Notatki instalatora...',
                      entries: installer,
                    ),
                    _compactLogEditor(
                      field: kCoordinationField,
                      hint: 'Koordynacja...',
                      entries: coordination,
                    ),
                    _compactLogEditor(
                      field: kChangesNotesField,
                      hint: 'Raporty / zmiany...',
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
