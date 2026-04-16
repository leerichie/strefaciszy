// lib/screens/project_today_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProjectTodayScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> projRef;
  final bool readOnly;
  final bool isAdmin;

  const ProjectTodayScreen({
    super.key,
    required this.projRef,
    required this.readOnly,
    required this.isAdmin,
  });

  @override
  State<ProjectTodayScreen> createState() => _ProjectTodayScreenState();
}

class _ProjectTodayScreenState extends State<ProjectTodayScreen> {
  static const String kInstallerField = 'currentInstaller';
  static const String kCoordinationField = 'currentCoordination';
  static const String kChangesNotesField = 'currentChangesNotes';

  static const String kUpdatedAt = 'updatedAt';
  static const String kUpdatedBy = 'updatedBy';
  static const String kUpdatedByName = 'updatedByName';

  bool _resolvedIsAdmin = false;
  bool _adminLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadIsAdmin();
  }

  String _fmt(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    final start = _startOfDay(now);
    final end = start.add(const Duration(days: 1));
    return !dt.isBefore(start) && dt.isBefore(end);
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

  Future<void> _loadIsAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _resolvedIsAdmin = false;
          _adminLoaded = true;
        });
      }
      return;
    }

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

    if (mounted) {
      setState(() {
        _resolvedIsAdmin = isAdmin;
        _adminLoaded = true;
      });
    }
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

    return user.email ?? '—';
  }

  DateTime? _entryMoment(Map<String, dynamic> e) {
    final updated = e[kUpdatedAt];
    if (updated is Timestamp) return updated.toDate().toLocal();

    final created = e['createdAt'];
    if (created is Timestamp) return created.toDate().toLocal();

    return null;
  }

  List<Map<String, dynamic>> _readTodayEntries(
    Map<String, dynamic> data,
    String field,
  ) {
    final raw = (data[field] as List?) ?? const [];
    final out = <Map<String, dynamic>>[];

    for (final item in raw) {
      if (item is! Map) continue;

      final m = Map<String, dynamic>.from(item);
      final when = _entryMoment(m);
      if (when == null) continue;
      if (!_isToday(when)) continue;

      out.add(m);
    }

    return out;
  }

  Future<DocumentReference<Map<String, dynamic>>?> _todayRwRef() async {
    final now = DateTime.now().toLocal();
    final startOfDay = DateTime(now.year, now.month, now.day);
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

  Future<void> _updateProjectEntry({
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
      'updatedByName': userName,
    });
  }

  Future<void> _toggleTaskDone({
    required String field,
    required Map<String, dynamic> oldEntry,
    required bool done,
  }) async {
    if (widget.readOnly) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': user.uid,
      'updatedByName': userName,
    });
  }

  Future<void> _deleteProjectEntry({
    required String field,
    required Map<String, dynamic> entry,
  }) async {
    if (widget.readOnly) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final entryId = (entry['id'] ?? '').toString();
    if (entryId.isEmpty) return;

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
      });
    });
  }

  Future<void> _createManualTodayCard() async {
    if (!_resolvedIsAdmin || widget.readOnly) return;

    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) return;

    String userName = authUser.displayName ?? '';
    if (userName.isEmpty) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(authUser.uid)
          .get();
      userName = userDoc.data()?['name'] as String? ?? authUser.email ?? '—';
    }

    final newMap = {
      'text': 'bla blaaa',
      'userName': userName,
      'createdAt': Timestamp.now(),
      'todayManualCard': true,
      'todayCardTitle': 'NOWY WPIS - ADMIN',
    };

    await widget.projRef.update({
      'notesList': FieldValue.arrayUnion([newMap]),
    });

    final rwRef = await _todayRwRef();
    if (rwRef != null) {
      await rwRef.update({
        'notesList': FieldValue.arrayUnion([newMap]),
      });
    }
  }

  Future<void> _updateNoteInline({
    required String oldText,
    required String oldUserName,
    required DateTime oldCreatedAt,
    required String newText,
    String? oldTitle,
    bool isManualCard = false,
  }) async {
    if (widget.readOnly) return;

    final trimmed = newText.trim();
    if (trimmed == oldText) return;

    final authUser = FirebaseAuth.instance.currentUser!;
    String userName = authUser.displayName ?? '';
    if (userName.isEmpty) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(authUser.uid)
          .get();
      userName = userDoc.data()?['name'] as String? ?? authUser.email!;
    }

    final now = DateTime.now();

    final oldMap = {
      'text': oldText,
      'userName': oldUserName,
      'createdAt': Timestamp.fromDate(oldCreatedAt),
      if (isManualCard) 'todayManualCard': true,
      if (isManualCard && oldTitle != null) 'todayCardTitle': oldTitle,
    };

    final newMap = {
      'text': trimmed,
      'userName': userName,
      'createdAt': Timestamp.fromDate(now),
      if (isManualCard) 'todayManualCard': true,
      if (isManualCard && oldTitle != null) 'todayCardTitle': oldTitle,
    };

    await widget.projRef.update({
      'notesList': FieldValue.arrayRemove([oldMap]),
    });
    await widget.projRef.update({
      'notesList': FieldValue.arrayUnion([newMap]),
    });

    final rwRef = await _todayRwRef();
    if (rwRef != null) {
      await rwRef.update({
        'notesList': FieldValue.arrayRemove([oldMap]),
      });
      await rwRef.update({
        'notesList': FieldValue.arrayUnion([newMap]),
      });
    }
  }

  Future<void> _updateManualCardTitle({
    required String oldText,
    required String oldUserName,
    required DateTime oldCreatedAt,
    required String oldTitle,
    required String newTitle,
  }) async {
    if (!_resolvedIsAdmin || widget.readOnly) return;

    final trimmed = newTitle.trim();
    if (trimmed.isEmpty || trimmed == oldTitle) return;

    final oldMap = {
      'text': oldText,
      'userName': oldUserName,
      'createdAt': Timestamp.fromDate(oldCreatedAt),
      'todayManualCard': true,
      'todayCardTitle': oldTitle,
    };

    final newMap = {
      'text': oldText,
      'userName': oldUserName,
      'createdAt': Timestamp.fromDate(oldCreatedAt),
      'todayManualCard': true,
      'todayCardTitle': trimmed,
    };

    await widget.projRef.update({
      'notesList': FieldValue.arrayRemove([oldMap]),
    });
    await widget.projRef.update({
      'notesList': FieldValue.arrayUnion([newMap]),
    });

    final rwRef = await _todayRwRef();
    if (rwRef != null) {
      await rwRef.update({
        'notesList': FieldValue.arrayRemove([oldMap]),
      });
      await rwRef.update({
        'notesList': FieldValue.arrayUnion([newMap]),
      });
    }
  }

  Future<void> _deleteNote({
    required String text,
    required String userName,
    required DateTime createdAt,
    bool isManualCard = false,
    String? manualTitle,
  }) async {
    if (widget.readOnly) return;
    if (!_resolvedIsAdmin) return;

    final map = {
      'text': text,
      'userName': userName,
      'createdAt': Timestamp.fromDate(createdAt),
      if (isManualCard) 'todayManualCard': true,
      if (isManualCard && manualTitle != null) 'todayCardTitle': manualTitle,
    };

    await widget.projRef.update({
      'notesList': FieldValue.arrayRemove([map]),
    });

    final rwRef = await _todayRwRef();
    if (rwRef != null) {
      await rwRef.update({
        'notesList': FieldValue.arrayRemove([map]),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canEditTodayScreen = _resolvedIsAdmin && !widget.readOnly;
    return Scaffold(
      appBar: AppBar(title: const Text('PEŁNY RAPORT - dzisiaj')),
      body: !_adminLoaded
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: widget.projRef.snapshots(),
              builder: (context, snap) {
                if (!snap.hasData || !snap.data!.exists) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snap.data!.data() ?? <String, dynamic>{};

                final installer = _readTodayEntries(data, kInstallerField)
                    .map(
                      (e) => {
                        'type': 'installer',
                        'field': kInstallerField,
                        'entry': e,
                      },
                    )
                    .toList();

                final coordination = _readTodayEntries(data, kCoordinationField)
                    .map(
                      (e) => {
                        'type': 'coordination',
                        'field': kCoordinationField,
                        'entry': e,
                      },
                    )
                    .toList();

                final todo = _readTodayEntries(data, kChangesNotesField)
                    .map(
                      (e) => {
                        'type': 'todo',
                        'field': kChangesNotesField,
                        'entry': e,
                      },
                    )
                    .toList();

                final rawNotes = (data['notesList'] as List?) ?? const [];
                final notes = <Map<String, dynamic>>[];

                for (int i = 0; i < rawNotes.length; i++) {
                  final item = rawNotes[i];
                  if (item is! Map) continue;

                  final m = Map<String, dynamic>.from(item);
                  final ts = m['createdAt'];
                  if (ts is! Timestamp) continue;

                  final dt = ts.toDate().toLocal();
                  if (!_isToday(dt)) continue;

                  notes.add({'type': 'note', 'noteIndex': i, 'entry': m});
                }

                final all = <Map<String, dynamic>>[
                  ...installer,
                  ...coordination,
                  ...todo,
                  ...notes,
                ];

                DateTime sortMoment(Map<String, dynamic> row) {
                  final entry = Map<String, dynamic>.from(row['entry'] as Map);
                  if (row['type'] == 'note') {
                    return (entry['createdAt'] as Timestamp).toDate().toLocal();
                  }
                  return _entryMoment(entry) ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                }

                all.sort((a, b) => sortMoment(b).compareTo(sortMoment(a)));

                if (all.isEmpty) {
                  return const Center(child: Text('Jeszcze pusto...'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  itemCount: all.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, i) {
                    final row = all[i];
                    final type = row['type'] as String;
                    final entry = Map<String, dynamic>.from(
                      row['entry'] as Map,
                    );

                    if (type == 'note') {
                      final text = (entry['text'] ?? '').toString();
                      final userName = (entry['userName'] ?? '').toString();
                      final createdAt = (entry['createdAt'] as Timestamp)
                          .toDate()
                          .toLocal();
                      final isManualCard = entry['todayManualCard'] == true;
                      final manualTitle = (entry['todayCardTitle'] ?? 'NOTE')
                          .toString();

                      return _TodayNoteCard(
                        title: isManualCard ? manualTitle : 'NOTE',
                        header: '${_fmt(createdAt)} • $userName',
                        text: text,
                        readOnly: !canEditTodayScreen,
                        canDelete: canEditTodayScreen,
                        titleEditable: isManualCard && canEditTodayScreen,
                        onTitleChanged: isManualCard
                            ? (value) async {
                                await _updateManualCardTitle(
                                  oldText: text,
                                  oldUserName: userName,
                                  oldCreatedAt: createdAt,
                                  oldTitle: manualTitle,
                                  newTitle: value,
                                );
                              }
                            : null,
                        onChanged: (value) async {
                          await _updateNoteInline(
                            oldText: text,
                            oldUserName: userName,
                            oldCreatedAt: createdAt,
                            newText: value,
                            oldTitle: isManualCard ? manualTitle : null,
                            isManualCard: isManualCard,
                          );
                        },
                        onDelete: () async {
                          final ok = await _confirmDeleteDialog();
                          if (!ok) return;

                          await _deleteNote(
                            text: text,
                            userName: userName,
                            createdAt: createdAt,
                            isManualCard: isManualCard,
                            manualTitle: isManualCard ? manualTitle : null,
                          );
                        },
                      );
                    }

                    final field = row['field'] as String;
                    final text = (entry['text'] ?? '').toString();
                    final isTask = entry['isTask'] == true;
                    final done = entry['done'] == true;

                    final createdAt = (entry['createdAt'] as Timestamp?)
                        ?.toDate()
                        .toLocal();
                    final createdByName =
                        (entry['createdByName'] as String?) ?? '';

                    final updatedAt = (entry[kUpdatedAt] as Timestamp?)
                        ?.toDate()
                        .toLocal();
                    final updatedByName =
                        (entry[kUpdatedByName] as String?) ?? '';

                    final headerTime = updatedAt ?? createdAt;
                    final headerName =
                        (updatedAt != null ? updatedByName : createdByName)
                            .trim();

                    final header = headerTime == null
                        ? '—'
                        : '${_fmt(headerTime)}'
                              '${headerName.isNotEmpty ? ' • $headerName' : ''}'
                              '${updatedAt != null ? ' (edyt.)' : ''}';

                    final label = field == kInstallerField
                        ? 'INSTALATOR'
                        : field == kCoordinationField
                        ? 'KOORDYNACJA'
                        : 'TODO';

                    final colorStr = (entry['color'] ?? 'black').toString();
                    final textColor = colorStr == 'red'
                        ? Colors.red
                        : colorStr == 'blue'
                        ? Colors.blue
                        : Colors.black;

                    return _TodayEntryCard(
                      label: label,
                      header: header,
                      text: text,
                      isTask: isTask,
                      done: done,
                      readOnly: !canEditTodayScreen,
                      textColor: textColor,
                      onChanged: (value) async {
                        await _updateProjectEntry(
                          field: field,
                          oldEntry: entry,
                          newText: value,
                        );
                      },
                      onToggleDone: isTask
                          ? (value) async {
                              await _toggleTaskDone(
                                field: field,
                                oldEntry: entry,
                                done: value,
                              );
                            }
                          : null,
                      onDelete: canEditTodayScreen
                          ? () async {
                              final ok = await _confirmDeleteDialog();
                              if (!ok) return;

                              await _deleteProjectEntry(
                                field: field,
                                entry: entry,
                              );
                            }
                          : null,
                    );
                  },
                );
              },
            ),
      floatingActionButton: canEditTodayScreen
          ? FloatingActionButton(
              onPressed: _createManualTodayCard,
              tooltip: 'Dodaj wpis',
              child: const Icon(Icons.add),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _TodayNoteCard extends StatefulWidget {
  final String title;
  final String header;
  final String text;
  final bool readOnly;
  final bool canDelete;
  final bool titleEditable;
  final Future<void> Function(String value)? onTitleChanged;
  final Future<void> Function(String value) onChanged;
  final Future<void> Function() onDelete;

  const _TodayNoteCard({
    required this.title,
    required this.header,
    required this.text,
    required this.readOnly,
    required this.canDelete,
    required this.titleEditable,
    required this.onTitleChanged,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_TodayNoteCard> createState() => _TodayNoteCardState();
}

class _TodayNoteCardState extends State<_TodayNoteCard> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _ctrl;
  late final FocusNode _titleFocus;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.title);
    _ctrl = TextEditingController(text: widget.text);
    _titleFocus = FocusNode();
    _focus = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _TodayNoteCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_titleFocus.hasFocus && _titleCtrl.text != widget.title) {
      _titleCtrl.text = widget.title;
    }

    if (!_focus.hasFocus && _ctrl.text != widget.text) {
      _ctrl.text = widget.text;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _ctrl.dispose();
    _titleFocus.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            widget.titleEditable
                ? TextField(
                    controller: _titleCtrl,
                    focusNode: _titleFocus,
                    minLines: 1,
                    maxLines: 1,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      height: 1.5,
                    ),
                    onSubmitted: (v) async {
                      await widget.onTitleChanged?.call(v);
                    },
                  )
                : Text(
                    widget.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
            const SizedBox(height: 1),
            Text(
              widget.header,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: widget.readOnly
                      ? Text(
                          widget.text,
                          style: const TextStyle(fontSize: 13, height: 1.1),
                        )
                      : TextField(
                          controller: _ctrl,
                          focusNode: _focus,
                          minLines: 1,
                          maxLines: null,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(fontSize: 13, height: 1.1),
                          onSubmitted: (v) async {
                            await widget.onChanged(v);
                          },
                        ),
                ),
                if (widget.canDelete && !widget.readOnly)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.red,
                        size: 20,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: const VisualDensity(
                        horizontal: -4,
                        vertical: -4,
                      ),
                      onPressed: widget.onDelete,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayEntryCard extends StatefulWidget {
  final String label;
  final String header;
  final String text;
  final bool isTask;
  final bool done;
  final bool readOnly;
  final Color textColor;
  final Future<void> Function(String value) onChanged;
  final Future<void> Function(bool value)? onToggleDone;
  final Future<void> Function()? onDelete;

  const _TodayEntryCard({
    required this.label,
    required this.header,
    required this.text,
    required this.isTask,
    required this.done,
    required this.readOnly,
    required this.textColor,
    required this.onChanged,
    required this.onToggleDone,
    required this.onDelete,
  });

  @override
  State<_TodayEntryCard> createState() => _TodayEntryCardState();
}

class _TodayEntryCardState extends State<_TodayEntryCard> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.text);
    _focus = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _TodayEntryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && _ctrl.text != widget.text) {
      _ctrl.text = widget.text;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              widget.header,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.isTask)
                  Padding(
                    padding: const EdgeInsets.only(right: 4, top: 0),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: Checkbox(
                        value: widget.done,
                        onChanged:
                            widget.readOnly || widget.onToggleDone == null
                            ? null
                            : (v) async {
                                await widget.onToggleDone!(v == true);
                              },
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: const VisualDensity(
                          horizontal: -4,
                          vertical: -4,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: widget.readOnly
                      ? Text(
                          widget.text,
                          style: TextStyle(
                            fontSize: 13,
                            color: widget.textColor,
                            height: 1.1,
                          ),
                        )
                      : TextField(
                          controller: _ctrl,
                          focusNode: _focus,
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
                            color: widget.textColor,
                            height: 1.1,
                          ),
                          onSubmitted: (v) async {
                            await widget.onChanged(v);
                          },
                        ),
                ),
                if (widget.onDelete != null && !widget.readOnly)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.red,
                        size: 20,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: const VisualDensity(
                        horizontal: -4,
                        vertical: -4,
                      ),
                      onPressed: widget.onDelete,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
