// screens/shopping_list_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:strefa_ciszy/screens/project_editor_screen.dart';
import 'package:strefa_ciszy/screens/scan_screen.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

enum _SortMode { time, project, user, nonProject }

class _ShoppingListScreenState extends State<ShoppingListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController tabCtrl;
  final newCtrl = TextEditingController();

  _SortMode _sortMode = _SortMode.time;

  @override
  void initState() {
    super.initState();
    tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    tabCtrl.dispose();
    newCtrl.dispose();
    super.dispose();
  }

  void openSortDialog() async {
    final res = await showDialog<_SortMode>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Sortowanie'),
        children: [
          RadioGroup<_SortMode>(
            groupValue: _sortMode,
            onChanged: (v) {
              Navigator.pop(ctx, v);
            },
            child: Column(
              children: const [
                RadioListTile<_SortMode>(
                  title: Text('Najnowszy'),
                  value: _SortMode.time,
                ),
                RadioListTile<_SortMode>(
                  title: Text('Projekt'),
                  value: _SortMode.project,
                ),
                RadioListTile<_SortMode>(
                  title: Text('User'),
                  value: _SortMode.user,
                ),
                RadioListTile<_SortMode>(
                  title: Text('Bez projektu'),
                  value: _SortMode.nonProject,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (res != null) {
      setState(() => _sortMode = res);
    }
  }

  String firstNameFromDisplayName(String? s) {
    final v = (s ?? '').trim();
    if (v.isEmpty) return 'User';
    final parts = v.split(RegExp(r'\s+'));
    return parts.isEmpty ? v : parts.first;
  }

  Future<String> resolveMyName(String uid) async {
    // 1) try FirebaseAuth displayName
    final authName = FirebaseAuth.instance.currentUser?.displayName;
    if ((authName ?? '').trim().isNotEmpty) {
      return firstNameFromDisplayName(authName);
    }

    // 2) try Firestore users/{uid}.name (your chat screen uses this)
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final name = (snap.data()?['name'] as String?)?.trim();
      if ((name ?? '').isNotEmpty) return firstNameFromDisplayName(name);
    } catch (_) {}

    return 'User';
  }

  Future<void> addItem() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final text = newCtrl.text.trim();
    if (text.isEmpty) return;

    newCtrl.clear();

    final myName = await resolveMyName(uid);

    await FirebaseFirestore.instance.collection('shopping_items').add({
      'text': text,
      'createdBy': uid,
      'createdByName': myName,
      'createdAt': FieldValue.serverTimestamp(),
      'bought': false,
      'boughtAt': null,
      'boughtBy': null,
      'boughtByName': null,
    });
  }

  Future<void> scanAndAdd() async {
    final res = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ScanScreen(
          returnCode: true,
          titleText: 'Skanuj kod',
          purpose: ScanPurpose.search,
        ),
      ),
    );

    final code = (res ?? '').trim();
    if (code.isEmpty) return;

    newCtrl.text = code;
    newCtrl.selection = TextSelection.collapsed(offset: code.length);

    await addItem();
  }

  Future<void> setBought({required String docId, required bool bought}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final myName = await resolveMyName(uid);

    final ref = FirebaseFirestore.instance
        .collection('shopping_items')
        .doc(docId);

    await ref.update({
      'bought': bought,
      'boughtAt': bought ? FieldValue.serverTimestamp() : null,
      'boughtBy': bought ? uid : null,
      'boughtByName': bought ? myName : null,
    });

    final snap = await ref.get();
    final data = snap.data();
    if (data == null) return;

    final sourceTaskId = (data['sourceTaskId'] ?? '').toString();
    final customerId = (data['customerId'] ?? '').toString();
    final projectId = (data['projectId'] ?? '').toString();

    if (sourceTaskId.isEmpty || customerId.isEmpty || projectId.isEmpty) return;

    final projRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(customerId)
        .collection('projects')
        .doc(projectId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final projSnap = await tx.get(projRef);
      if (!projSnap.exists) return;

      final proj = projSnap.data() ?? <String, dynamic>{};
      final raw = (proj['currentCoordination'] as List?) ?? const [];

      final updated = raw.map((e) {
        if (e is! Map) return e;

        final id = (e['id']?.toString() ?? '');
        if (id != sourceTaskId) return e;

        final m = Map<String, dynamic>.from(e);
        m['done'] = bought;
        m['updatedAt'] = Timestamp.now();
        m['updatedBy'] = uid;
        m['updatedByName'] = myName;
        return m;
      }).toList();

      tx.update(projRef, {'currentCoordination': updated});
    });
  }

  Future<void> deleteItem(String docId) async {
    final ref = FirebaseFirestore.instance
        .collection('shopping_items')
        .doc(docId);

    final snap = await ref.get();
    final data = snap.data();

    if (data != null) {
      final sourceTaskId = (data['sourceTaskId'] ?? '').toString();
      final customerId = (data['customerId'] ?? '').toString();
      final projectId = (data['projectId'] ?? '').toString();

      if (sourceTaskId.isNotEmpty &&
          customerId.isNotEmpty &&
          projectId.isNotEmpty) {
        final projRef = FirebaseFirestore.instance
            .collection('customers')
            .doc(customerId)
            .collection('projects')
            .doc(projectId);

        await FirebaseFirestore.instance.runTransaction((tx) async {
          final projSnap = await tx.get(projRef);
          if (!projSnap.exists) return;

          final proj = projSnap.data() ?? <String, dynamic>{};
          final raw = (proj['currentCoordination'] as List?) ?? const [];

          final updated = raw.where((e) {
            if (e is! Map) return true;
            return (e['id']?.toString() ?? '') != sourceTaskId;
          }).toList();

          tx.update(projRef, {'currentCoordination': updated});
        });
      }
    }

    await ref.delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> activeStream() {
    return FirebaseFirestore.instance
        .collection('shopping_items')
        .where('bought', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> historyStream() {
    return FirebaseFirestore.instance
        .collection('shopping_items')
        .where('bought', isEqualTo: true)
        .orderBy('boughtAt', descending: true)
        .limit(200)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Nie zalogowany')));
    }

    return AppScaffold(
      title: 'Zakupy',
      // titleWidget: const Text('Lista zakupów', style: TextStyle(fontSize: 15)),
      showBackOnMobile: true,
      showBackOnWeb: true,
      showPersistentDrawerOnWeb: true,
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Material(
              color: Colors.transparent,
              child: TabBar(
                controller: tabCtrl,
                tabs: const [
                  Tab(text: 'Zapotrzebowanie'),
                  Tab(text: 'Historia zakupów'),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: newCtrl,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => addItem(),
                      decoration: InputDecoration(
                        hintText: 'Wpisz nazwa lub skanuj…',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: IconButton(
                          tooltip: 'Skanuj',
                          icon: const Icon(Icons.qr_code_scanner),
                          onPressed: scanAndAdd,
                        ),
                      ),
                    ),
                  ),
                  // const SizedBox(width: 8),
                  // SizedBox(
                  //   height: 44,
                  //   child: ElevatedButton.icon(
                  //     onPressed: _addItem,
                  //     icon: const Icon(Icons.add),
                  //     label: const Text('Dodaj'),
                  //   ),
                  // ),
                  const SizedBox(width: 6),

                  IconButton(
                    tooltip: 'Sortuj',
                    icon: const Icon(Icons.sort),
                    onPressed: openSortDialog,
                  ),
                ],
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: tabCtrl,
                children: [
                  _ItemsList(
                    stream: activeStream(),
                    onToggleBought: (id, v) => setBought(docId: id, bought: v),
                    onDelete: deleteItem,
                    emptyText: 'brak.',
                    showRestore: false,
                    sortMode: _sortMode,
                  ),
                  _ItemsList(
                    stream: historyStream(),
                    onToggleBought: (id, v) => setBought(docId: id, bought: v),
                    onDelete: deleteItem,
                    emptyText: 'Nie kupiono nic jeszcze.',
                    showRestore: true,
                    sortMode: _sortMode,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemsList extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final void Function(String docId, bool bought) onToggleBought;
  final void Function(String docId) onDelete;
  final String emptyText;
  final bool showRestore;
  final _SortMode sortMode;

  const _ItemsList({
    required this.stream,
    required this.onToggleBought,
    required this.onDelete,
    required this.emptyText,
    required this.showRestore,
    required this.sortMode,
  });

  @override
  Widget build(BuildContext context) {
    Color bgForProject(String projectId) {
      final palette = <Color>[
        const Color(0xFFF3F6FF), // very light blue
        const Color(0xFFF4FFF6), // very light green
        const Color(0xFFFFF6F2), // very light orange
        const Color(0xFFFFF4FA), // very light pink
        const Color(0xFFF7F3FF), // very light purple
        const Color(0xFFFFFFF1), // very light yellow
      ];

      // deterministic hash
      var h = 0;
      for (final c in projectId.codeUnits) {
        h = (h * 31 + c) & 0x7fffffff;
      }
      return palette[h % palette.length];
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var docs = snap.data?.docs ?? const [];

        docs = docs.toList();

        docs.sort((a, b) {
          final da = a.data();
          final db = b.data();

          String pa = (da['projectName'] ?? '').toString();
          String pb = (db['projectName'] ?? '').toString();

          String ua = (da['createdByName'] ?? '').toString();
          String ub = (db['createdByName'] ?? '').toString();

          Timestamp? ta = da['createdAt'];
          Timestamp? tb = db['createdAt'];

          switch (sortMode) {
            case _SortMode.project:
              return pa.compareTo(pb);

            case _SortMode.user:
              return ua.compareTo(ub);

            case _SortMode.nonProject:
              final aEmpty = pa.isEmpty;
              final bEmpty = pb.isEmpty;
              if (aEmpty != bEmpty) return aEmpty ? -1 : 1;
              return (tb?.millisecondsSinceEpoch ?? 0).compareTo(
                ta?.millisecondsSinceEpoch ?? 0,
              );

            case _SortMode.time:
            default:
              return (tb?.millisecondsSinceEpoch ?? 0).compareTo(
                ta?.millisecondsSinceEpoch ?? 0,
              );
          }
        });
        if (docs.isEmpty) {
          return Center(child: Text(emptyText));
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i];
            final data = d.data();

            final customerId = (data['customerId'] ?? '').toString().trim();
            final projectName = (data['projectName'] ?? '').toString().trim();
            final projectId = (data['projectId'] ?? '').toString().trim();

            final hasProjectLink =
                customerId.isNotEmpty &&
                projectId.isNotEmpty &&
                projectName.isNotEmpty;

            final text = (data['text'] ?? '').toString().trim();
            final createdByName = (data['createdByName'] ?? 'User').toString();

            String short(String s, int max) {
              final t = s.trim();
              if (t.length <= max) return t;
              return '${t.substring(0, max - 1)}…';
            }

            // final projectName = (data['projectName'] ?? '').toString().trim();
            // final projectId = (data['projectId'] ?? '').toString().trim();
            final cardColor = projectId.isEmpty
                ? Colors.grey.shade100
                : bgForProject(projectId);

            // final projTag = (projectId.isNotEmpty && projectName.isNotEmpty)
            //     ? '  •  ${short(projectName, 18)}'
            //     : '';
            final bought = (data['bought'] == true);

            if (text.isEmpty) return const SizedBox.shrink();

            final ts = (data['createdAt'] is Timestamp)
                ? (data['createdAt'] as Timestamp).toDate()
                : null;
            final tsText = ts == null
                ? ''
                : DateFormat('dd/MM HH:mm').format(ts);

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: cardColor,
                borderRadius: BorderRadius.circular(10),
                child: ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  minLeadingWidth: 0,
                  horizontalTitleGap: 8,

                  title: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: [
                      Text(
                        tsText.isEmpty
                            ? createdByName
                            : '$createdByName  •  $tsText',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                          height: 1.0,
                        ),
                      ),
                      if (hasProjectLink) ...[
                        const Text(
                          '•',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                            height: 1.0,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ProjectEditorScreen(
                                  customerId: customerId,
                                  projectId: projectId,
                                  isAdmin: false,
                                ),
                              ),
                            );
                          },
                          child: Text(
                            short(projectName, 18),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  leading: Checkbox(
                    value: bought,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    onChanged: (v) {
                      if (v == null) return;
                      onToggleBought(d.id, v);
                    },
                  ),

                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showRestore)
                        IconButton(
                          tooltip: 'Przywróć',
                          icon: const Icon(Icons.undo, size: 18),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          onPressed: () => onToggleBought(d.id, false),
                        ),
                      IconButton(
                        tooltip: 'Usuń',
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Na pewno usunąć?'),
                              content: Text(text),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Anuluj'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Usuń'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            onDelete(d.id);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
