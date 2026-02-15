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

  static const String kChangesTasksField = 'currentChangesTasks';

  final _installerCtrl = TextEditingController();
  final _coordCtrl = TextEditingController();
  final _changesCtrl = TextEditingController();

  Timer? _installerDebounce;
  Timer? _coordDebounce;
  Timer? _changesDebounce;

  bool _hydratedInstaller = false;
  bool _hydratedCoord = false;
  bool _hydratedChanges = false;

  @override
  void dispose() {
    _installerDebounce?.cancel();
    _coordDebounce?.cancel();
    _changesDebounce?.cancel();

    _installerCtrl.dispose();
    _coordCtrl.dispose();
    _changesCtrl.dispose();
    super.dispose();
  }

  Future<void> _upsertLiveEntry({
    required String field,
    required String text,
  }) async {
    if (widget.readOnly) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userName = await _resolveUserName(user);
    final trimmed = text.trim();

    if (trimmed.isEmpty) return;

    final liveId = '${user.uid}::$field';

    final snap = await widget.projRef.get();
    final data = snap.data() ?? <String, dynamic>{};
    final raw = (data[field] as List<dynamic>?) ?? const [];
    final list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    final old = list.firstWhere(
      (e) => (e['id'] as String?) == liveId,
      orElse: () => <String, dynamic>{},
    );

    final entry = <String, dynamic>{
      'id': liveId,
      'text': trimmed,
      'createdAt': Timestamp.now(),
      'createdBy': user.uid,
      'createdByName': userName,
    };

    if (old.isNotEmpty) {
      await widget.projRef.update({
        field: FieldValue.arrayRemove([old]),
      });
    }

    await widget.projRef.update({
      field: FieldValue.arrayUnion([entry]),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': user.uid,
    });
  }

  Widget _historyView(List<Map<String, dynamic>> entries) {
    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 10),
        child: Text('Brak wpisów', style: TextStyle(color: Colors.black54)),
      );
    }

    entries.sort((a, b) {
      final ta = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
      final tb = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
      return tb.compareTo(ta);
    });

    const gap = Duration(minutes: 10);

    String? lastUser;
    DateTime? lastTime;

    final spans = <InlineSpan>[];

    for (final e in entries) {
      final dt = (e['createdAt'] as Timestamp?)?.toDate();
      final user = (e['createdByName'] as String?) ?? '';
      final text = (e['text'] as String?) ?? '';
      if (text.trim().isEmpty) continue;

      final showHeader =
          dt != null &&
          (lastUser != user ||
              lastTime == null ||
              lastTime.difference(dt).abs() >= gap);

      if (showHeader) {
        spans.add(
          TextSpan(
            text: '${_fmt(dt)}${user.isNotEmpty ? ' • $user' : ''}\n',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        );
      }

      spans.add(
        TextSpan(
          text: '$text\n\n',
          style: const TextStyle(fontSize: 14, height: 1.25),
        ),
      );

      lastUser = user;
      lastTime = dt;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SelectableText.rich(TextSpan(children: spans)),
    );
  }

  Widget _editorTab({
    required String title,
    required TextEditingController controller,
    required String hint,
    required List<Map<String, dynamic>> entries,
    required void Function(String) onChanged,
    Widget? extraBottom,
  }) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _tabHeaderTitle(title),
        const SizedBox(height: 10),
        _bigEditor(controller: controller, hint: hint, onChanged: onChanged),
        _historyView(entries),
        if (extraBottom != null) ...[const SizedBox(height: 16), extraBottom],
      ],
    );
  }

  Widget _bigEditor({
    required TextEditingController controller,
    required String hint,
    required void Function(String) onChanged,
  }) {
    return TextField(
      controller: controller,
      enabled: !widget.readOnly,
      maxLines: null,
      minLines: 6,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        hintText: hint,
      ),
      onChanged: onChanged,
    );
  }

  Future<DocumentReference<Map<String, dynamic>>?> _todayRwRef() async {
    final start = DateTime.now().toLocal();
    final startOfDay = DateTime(start.year, start.month, start.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snap = await widget.projRef
        .collection('rw_documents')
        .where('type', isEqualTo: 'RW')
        .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
        .where('createdAt', isLessThan: endOfDay)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return snap.docs.first.reference;
  }

  Future<void> _appendNoteToTodayRw(Map<String, dynamic> noteMap) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final rwRef = await _todayRwRef();

    if (rwRef != null) {
      await rwRef.update({
        'notesList': FieldValue.arrayUnion([noteMap]),
      });
      return;
    }

    final now = DateTime.now();

    final newRwRef = widget.projRef.collection('rw_documents').doc();

    await newRwRef.set({
      'type': 'RW',
      'customerId': widget.customerId,
      'projectId': widget.projectId,
      'customerName': widget.customerName,
      'projectName': widget.projectName,
      'createdDay': DateTime(now.year, now.month, now.day),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': user.uid,
      'createdByName': noteMap['userName'] ?? '',
      'items': <Map<String, dynamic>>[],
      'notesList': [noteMap],
    });
  }

  Future<void> _addTask() async {
    if (widget.readOnly) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userName = await _resolveUserName(user);

    String selectedColor = 'black';
    String text = '';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nowe zadanie'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: selectedColor,
              items: const [
                DropdownMenuItem(
                  value: 'black',
                  child: Text('Czarny – Normalne'),
                ),
                DropdownMenuItem(
                  value: 'blue',
                  child: Text('Niebieski – Dodatkowe'),
                ),
              ],
              onChanged: (v) {
                if (v != null) selectedColor = v;
              },
            ),
            const SizedBox(height: 12),
            TextField(
              minLines: 2,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Treść zadania...',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => text = v,
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

    if (ok != true) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final id = widget.projRef.collection('_tmp').doc().id;

    final task = {
      'id': id,
      'text': trimmed,
      'color': selectedColor,
      'createdAt': Timestamp.now(),
      'createdBy': user.uid,
      'createdByName': userName,
      'done': false,
      'doneAt': null,
      'doneBy': null,
      'doneByName': null,
    };

    await widget.projRef.update({
      kChangesTasksField: FieldValue.arrayUnion([task]),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': user.uid,
    });
  }

  Widget _tasksList(List<Map<String, dynamic>> tasks) {
    if (tasks.isEmpty) return const SizedBox();

    tasks.sort((a, b) {
      final ta = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
      final tb = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
      return tb.compareTo(ta);
    });

    return Column(
      children: tasks.map((task) {
        final isDone = task['done'] == true;
        final color = task['color'] == 'blue' ? Colors.blue : Colors.black;

        final dt = (task['createdAt'] as Timestamp?)?.toDate();
        final createdByName = (task['createdByName'] as String?) ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: isDone,
                onChanged: isDone ? null : (_) => _toggleTaskDone(task),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (dt != null)
                      Text(
                        '${_fmt(dt)}${createdByName.isNotEmpty ? ' • $createdByName' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    if (dt != null) const SizedBox(height: 6),
                    Text(
                      task['text'] ?? '',
                      style: TextStyle(
                        color: color,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _toggleTaskDone(Map<String, dynamic> task) async {
    if (widget.readOnly) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userName = await _resolveUserName(user);

    final updatedTask = Map<String, dynamic>.from(task);

    final now = Timestamp.now();

    updatedTask['done'] = true;
    updatedTask['doneAt'] = now;
    updatedTask['doneBy'] = user.uid;
    updatedTask['doneByName'] = userName;

    await widget.projRef.update({
      kChangesTasksField: FieldValue.arrayRemove([task]),
    });

    await widget.projRef.update({
      kChangesTasksField: FieldValue.arrayUnion([updatedTask]),
    });

    final noteMap = {
      'text': updatedTask['text'],
      'userName': userName,
      'createdAt': now,
      'color': updatedTask['color'],
    };

    await widget.projRef.update({
      'notesList': FieldValue.arrayUnion([noteMap]),
    });
    await _appendNoteToTodayRw(noteMap);
  }

  Widget _legacyBox({
    required String legacyText,
    required VoidCallback? onImport,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        border: Border.all(color: Colors.orange.shade400),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stare BIEŻĄCE (legacy)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade900,
            ),
          ),
          const SizedBox(height: 6),
          Text(legacyText, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'stary wpisy.',
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.move_down),
                label: const Text('Przenieś'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _importLegacyCurrentText(String legacyText) async {
    if (widget.readOnly) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userName = await _resolveUserName(user);

    final id = widget.projRef.collection('_tmp').doc().id;

    final entry = <String, dynamic>{
      'id': id,
      'text': legacyText.trim(),
      'createdAt': Timestamp.now(),
      'createdBy': user.uid,
      'createdByName': userName,
    };

    await widget.projRef.update({
      kChangesNotesField: FieldValue.arrayUnion([entry]),
      kLegacyCurrentTextField: FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': user.uid,
    });
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

  Future<void> _addEntry(String field) async {
    if (widget.readOnly) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userName = await _resolveUserName(user);

    String text = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dodaj wpis'),
        content: TextField(
          autofocus: true,
          minLines: 2,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'Wpisz tekst...',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => text = v,
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

    if (ok != true) return;

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final id = widget.projRef.collection('_tmp').doc().id;

    final entry = <String, dynamic>{
      'id': id,
      'text': trimmed,
      'createdAt': Timestamp.now(),
      'createdBy': user.uid,
      'createdByName': userName,
    };

    await widget.projRef.update({
      field: FieldValue.arrayUnion([entry]),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': user.uid,
    });
  }

  List<Map<String, dynamic>> _readEntries(
    Map<String, dynamic> data,
    String field,
  ) {
    final raw = (data[field] as List<dynamic>?) ?? const [];
    final list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    //   newest -> oldest
    list.sort((a, b) {
      final ta =
          (a['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final tb =
          (b['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });

    return list;
  }

  Widget _tabHeaderTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
    );
  }

  Widget _zmianyTabBody({
    required List<Map<String, dynamic>> notes,
    required List<Map<String, dynamic>> tasks,
    required String legacyText,
  }) {
    final hasLegacy = legacyText.trim().isNotEmpty;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _tabHeaderTitle('Raporty/Zmiany'),
        const SizedBox(height: 10),

        _bigEditor(
          controller: _changesCtrl,
          hint: 'Raporty / zmiany...',
          onChanged: (v) {
            _changesDebounce?.cancel();
            _changesDebounce = Timer(const Duration(milliseconds: 600), () {
              _upsertLiveEntry(field: kChangesNotesField, text: v);
            });
          },
        ),

        if (hasLegacy) ...[
          const SizedBox(height: 12),
          _legacyBox(
            legacyText: legacyText,
            onImport: widget.readOnly
                ? null
                : () => _importLegacyCurrentText(legacyText),
          ),
        ],

        _historyView(notes),

        const SizedBox(height: 16),

        Row(
          children: [
            const Text(
              'Zadania',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: widget.readOnly ? null : _addTask,
            ),
          ],
        ),
        const SizedBox(height: 8),
        _tasksList(tasks),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Align(
          //   alignment: Alignment.centerLeft,
          //   child: Text(
          //     'BIEŻĄCE',
          //     style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          //   ),
          // ),
          // const SizedBox(height: 8),
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
                Tab(text: 'Raporty/Zmiany'),
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

                final tasks = _readEntries(data, kChangesTasksField);

                if (!_hydratedInstaller && installer.isNotEmpty) {
                  _installerCtrl.text =
                      (installer.first['text'] as String?) ?? '';
                  _hydratedInstaller = true;
                }
                if (!_hydratedCoord && coordination.isNotEmpty) {
                  _coordCtrl.text =
                      (coordination.first['text'] as String?) ?? '';
                  _hydratedCoord = true;
                }
                if (!_hydratedChanges && changesNotes.isNotEmpty) {
                  _changesCtrl.text =
                      (changesNotes.first['text'] as String?) ?? '';
                  _hydratedChanges = true;
                }

                return TabBarView(
                  children: [
                    _editorTab(
                      title: 'Instalator',
                      controller: _installerCtrl,
                      hint: 'Notatki instalatora...',
                      entries: installer,
                      onChanged: (v) {
                        _installerDebounce?.cancel();
                        _installerDebounce = Timer(
                          const Duration(milliseconds: 600),
                          () {
                            _upsertLiveEntry(field: kInstallerField, text: v);
                          },
                        );
                      },
                    ),
                    _editorTab(
                      title: 'Koordynacja',
                      controller: _coordCtrl,
                      hint: 'Koordynacja...',
                      entries: coordination,
                      onChanged: (v) {
                        _coordDebounce?.cancel();
                        _coordDebounce = Timer(
                          const Duration(milliseconds: 600),
                          () {
                            _upsertLiveEntry(
                              field: kCoordinationField,
                              text: v,
                            );
                          },
                        );
                      },
                    ),
                    _zmianyTabBody(
                      notes: changesNotes,
                      tasks: tasks,
                      legacyText: legacyCurrentText,
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
