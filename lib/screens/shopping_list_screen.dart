// screens/shopping_list_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:strefa_ciszy/screens/scan_screen.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _newCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _newCtrl.dispose();
    super.dispose();
  }

  String _firstNameFromDisplayName(String? s) {
    final v = (s ?? '').trim();
    if (v.isEmpty) return 'User';
    final parts = v.split(RegExp(r'\s+'));
    return parts.isEmpty ? v : parts.first;
  }

  Future<String> _resolveMyName(String uid) async {
    // 1) try FirebaseAuth displayName
    final authName = FirebaseAuth.instance.currentUser?.displayName;
    if ((authName ?? '').trim().isNotEmpty) {
      return _firstNameFromDisplayName(authName);
    }

    // 2) try Firestore users/{uid}.name (your chat screen uses this)
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final name = (snap.data()?['name'] as String?)?.trim();
      if ((name ?? '').isNotEmpty) return _firstNameFromDisplayName(name);
    } catch (_) {}

    return 'User';
  }

  Future<void> _addItem() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final text = _newCtrl.text.trim();
    if (text.isEmpty) return;

    _newCtrl.clear();

    final myName = await _resolveMyName(uid);

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

  Future<void> _scanAndAdd() async {
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

    _newCtrl.text = code;
    _newCtrl.selection = TextSelection.collapsed(offset: code.length);

    await _addItem();
  }

  Future<void> _setBought({required String docId, required bool bought}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final myName = await _resolveMyName(uid);

    await FirebaseFirestore.instance
        .collection('shopping_items')
        .doc(docId)
        .update({
          'bought': bought,
          'boughtAt': bought ? FieldValue.serverTimestamp() : null,
          'boughtBy': bought ? uid : null,
          'boughtByName': bought ? myName : null,
        });
  }

  Future<void> _deleteItem(String docId) async {
    await FirebaseFirestore.instance
        .collection('shopping_items')
        .doc(docId)
        .delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _activeStream() {
    return FirebaseFirestore.instance
        .collection('shopping_items')
        .where('bought', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _historyStream() {
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
      title: '',
      titleWidget: const Text('Lista zakupów', style: TextStyle(fontSize: 15)),
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
                controller: _tabCtrl,
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
                      controller: _newCtrl,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addItem(),
                      decoration: InputDecoration(
                        hintText: 'Wpisz nazwa lub skanuj…',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: IconButton(
                          tooltip: 'Skanuj',
                          icon: const Icon(Icons.qr_code_scanner),
                          onPressed: _scanAndAdd,
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
                ],
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _ItemsList(
                    stream: _activeStream(),
                    onToggleBought: (id, v) => _setBought(docId: id, bought: v),
                    onDelete: _deleteItem,
                    emptyText: 'brak.',
                    showRestore: false,
                  ),
                  _ItemsList(
                    stream: _historyStream(),
                    onToggleBought: (id, v) => _setBought(docId: id, bought: v),
                    onDelete: _deleteItem,
                    emptyText: 'Nie kupiono nic jeszcze.',
                    showRestore: true,
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

  const _ItemsList({
    required this.stream,
    required this.onToggleBought,
    required this.onDelete,
    required this.emptyText,
    required this.showRestore,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return Center(child: Text(emptyText));
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i];
            final data = d.data();

            final text = (data['text'] ?? '').toString().trim();
            final createdByName = (data['createdByName'] ?? 'User').toString();
            final bought = (data['bought'] == true);

            if (text.isEmpty) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),

                  // This is the “name above the items” feel from your screenshot
                  title: Text(
                    createdByName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black54,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(text, style: const TextStyle(fontSize: 14)),
                  ),

                  leading: Checkbox(
                    value: bought,
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
                          icon: const Icon(Icons.undo),
                          onPressed: () => onToggleBought(d.id, false),
                        ),
                      IconButton(
                        tooltip: 'Usuń',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => onDelete(d.id),
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
