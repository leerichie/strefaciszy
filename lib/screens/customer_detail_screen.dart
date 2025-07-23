// lib/screens/customer_detail_screen.dart

import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:strefa_ciszy/screens/contacts_list_screen.dart';
import 'package:strefa_ciszy/screens/scan_screen.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';
import 'project_editor_screen.dart';

class CustomerDetailScreen extends StatefulWidget {
  final String customerId;
  final bool isAdmin;

  const CustomerDetailScreen({
    super.key,
    required this.customerId,
    required this.isAdmin,
  });

  @override
  _CustomerDetailScreenState createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late final DocumentReference _customerRef;
  late final CollectionReference _projectsCol;
  late final TextEditingController _searchController;
  String _search = '';
  Set<String> _favProjectIds = {};
  late final StreamSubscription<QuerySnapshot> _favsSub;

  void _editCustomerName() async {
    String newName = '';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zmień nazwa klienta'),
        content: TextField(
          autofocus: true,
          decoration: InputDecoration(hintText: 'Nowa nazwa'),
          onChanged: (v) => newName = v.trim(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () {
              if (newName.isNotEmpty) {
                _customerRef.update({'name': newName});
                Navigator.pop(ctx);
              }
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
  }

  Future<void> _editProjects() async {
    final snap = await _projectsCol.orderBy('createdAt').get();
    final docs = snap.docs;

    final edits = {
      for (var d in docs)
        d.id: (d.data() as Map<String, dynamic>)['title'] as String,
    };

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edytuj projekty'),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(ctx).size.height * 0.4,
          child: StatefulBuilder(
            builder: (ctx2, setState) {
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (_, i) {
                  final doc = docs[i];
                  return TextFormField(
                    initialValue: edits[doc.id],
                    decoration: InputDecoration(labelText: 'Projekt:'),
                    onChanged: (v) => setState(() => edits[doc.id] = v.trim()),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () async {
              for (var doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                final oldTitle = data['title'] as String;
                final newTitle = edits[doc.id]!;
                if (newTitle.isNotEmpty && newTitle != oldTitle) {
                  await _projectsCol.doc(doc.id).update({'title': newTitle});
                }
              }
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _customerRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId);
    _projectsCol = _customerRef.collection('projects');
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _favsSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favouriteProjects')
        .snapshots()
        .listen((snap) {
          setState(() {
            _favProjectIds = snap.docs.map((d) => d.id).toSet();
          });
        });
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _favsSub.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    FocusScope.of(context).unfocus();
    setState(() {
      _searchController.clear();
      _search = '';
    });
  }

  Future<void> _toggleFavouriteProjects(String projectId, String title) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final favDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favouriteProjects')
        .doc(projectId);

    if (_favProjectIds.contains(projectId)) {
      await favDoc.delete();
    } else {
      await favDoc.set({'customerId': widget.customerId, 'title': title});
    }
  }

  Future<void> _renameProject(String id, String currentTitle) async {
    String newTitle = currentTitle;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zmień nazwę projektu'),
        content: TextField(
          autofocus: true,
          controller: TextEditingController(text: currentTitle),
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
              if (newTitle.isNotEmpty && newTitle != currentTitle) {
                _projectsCol.doc(id).update({'title': newTitle});
              }
              Navigator.pop(ctx);
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
    setState(() {});
  }

  Future<void> _addProject() async {
    String title = '';
    DateTime? startDate;
    DateTime? estimatedEndDate;
    String costStr = '';

    final custSnap = await _customerRef.get();
    final realContactId =
        (custSnap.data()! as Map<String, dynamic>)['contactId'] as String?;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Nowy Projekt'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Nazwa projektu',
                  ),
                  onChanged: (v) => title = v.trim(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        startDate == null
                            ? 'Start'
                            : DateFormat(
                                'dd.MM.yyyy',
                                'pl_PL',
                              ).format(startDate!),
                      ),
                    ),
                    TextButton(
                      child: const Text('Wybieraj'),
                      onPressed: () async {
                        final dt = await showDatePicker(
                          context: ctx,
                          initialDate: startDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          locale: const Locale('pl', 'PL'),
                        );
                        if (dt != null) setState(() => startDate = dt);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        estimatedEndDate == null
                            ? 'Oczek. Koniec'
                            : DateFormat(
                                'dd.MM.yyyy',
                                'pl_PL',
                              ).format(estimatedEndDate!),
                      ),
                    ),
                    TextButton(
                      child: const Text('Wybieraj'),
                      onPressed: () async {
                        final dt = await showDatePicker(
                          context: ctx,
                          initialDate: estimatedEndDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          locale: const Locale('pl', 'PL'),
                        );
                        if (dt != null) setState(() => estimatedEndDate = dt);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(labelText: 'Oszac. koszt'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => costStr = v.trim(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Anuluj'),
            ),
            ElevatedButton(
              onPressed: () {
                if (title.isEmpty) return;
                final data = <String, dynamic>{
                  'title': title,
                  'status': 'draft',
                  'contactId': realContactId,
                  'customerId': widget.customerId,
                  'createdAt': FieldValue.serverTimestamp(),
                  'createdBy': DateTime.now().millisecondsSinceEpoch.toString(),
                  'items': <Map<String, dynamic>>[],
                  if (startDate != null)
                    'startDate': Timestamp.fromDate(startDate!),
                  if (estimatedEndDate != null)
                    'estimatedEndDate': Timestamp.fromDate(estimatedEndDate!),
                };
                final cost = double.tryParse(costStr.replaceAll(',', '.'));
                if (cost != null) data['estimatedCost'] = cost;
                _projectsCol.add(data);
                Navigator.pop(ctx);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.isAdmin;
    final titleStreamWidget = FutureBuilder<DocumentSnapshot>(
      future: _customerRef.get(),
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Text('…');
        }
        final data = snap.data?.data() as Map<String, dynamic>?;
        final name = data?['name'] as String? ?? '';
        return GestureDetector(
          onTap: widget.isAdmin ? _editCustomerName : null,
          onLongPress: widget.isAdmin ? _editCustomerName : null,
          child: AutoSizeText(name, maxLines: 1, minFontSize: 8),
        );
      },
    );

    return AppScaffold(
      title: '',
      titleWidget: titleStreamWidget,
      centreTitle: true,

      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Szukaj projektu…',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _search = v.trim()),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Resetuj filtr',
                icon: const Icon(Icons.refresh),
                onPressed: _resetFilters,
              ),
            ],
          ),
        ),
      ),
      actions: [Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0))],

      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _projectsCol
                  .where('status', whereIn: ['draft', 'RW', 'MM'])
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final docs = snap.data!.docs;
                final filtered = _search.isEmpty
                    ? docs
                    : docs.where((d) {
                        final title = (d['title'] ?? '')
                            .toString()
                            .toLowerCase();
                        return title.contains(_search.toLowerCase());
                      }).toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('Nie znaleziono projektów.'));
                }
                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final d = filtered[i];
                    final data = d.data()! as Map<String, dynamic>;
                    return ListTile(
                      title: InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProjectEditorScreen(
                              customerId: widget.customerId,
                              projectId: d.id,
                              isAdmin: widget.isAdmin,
                            ),
                          ),
                        ),
                        // long tap rename project
                        onLongPress: widget.isAdmin
                            ? () => _renameProject(
                                d.id,
                                data['title'] as String? ?? '',
                              )
                            : null,
                        child: Text(data['title'] ?? '—'),
                      ),

                      // subtitle: Text('Status: ${data['status']}'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProjectEditorScreen(
                            customerId: widget.customerId,
                            projectId: d.id,
                            isAdmin: isAdmin,
                          ),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // faves
                          IconButton(
                            icon: Icon(
                              _favProjectIds.contains(d.id)
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.amber,
                            ),
                            tooltip: _favProjectIds.contains(d.id)
                                ? 'Usuń z ulubionych'
                                : 'Dodaj do ulubionych',
                            onPressed: () => _toggleFavouriteProjects(
                              d.id,
                              data['title'] as String? ?? '',
                            ),
                          ),
                          // badge
                          FutureBuilder<QuerySnapshot>(
                            future: _projectsCol
                                .doc(d.id)
                                .collection('rw_documents')
                                .get(),
                            builder: (ctx2, snap2) {
                              if (snap2.connectionState ==
                                  ConnectionState.waiting) {
                                return const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                );
                              }
                              final count = snap2.data?.docs.length ?? 0;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'RW: $count',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            },
                          ),

                          if (widget.isAdmin) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Usuń projekt',
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx2) => AlertDialog(
                                    title: const Text('Usuń projekt?'),
                                    content: Text(
                                      'Na pewno usunąć projekt "${data['title']}"?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx2, false),
                                        child: const Text('Anuluj'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx2, true),
                                        child: const Text('Usuń'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true) {
                                  await _projectsCol.doc(d.id).delete();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Projekt usunięty'),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _addProject,
        child: const Icon(Icons.playlist_add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        elevation: 4,
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: 'Contacts',
                icon: const Icon(Icons.people),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ContactsListScreen(
                      isAdmin: widget.isAdmin,
                      customerId: widget.customerId,
                    ),
                  ),
                ),
              ),

              SizedBox(width: 48),

              // IconButton(
              //   tooltip: 'Edytuj projekty',
              //   icon: const Icon(Icons.edit),
              //   onPressed: _editProjects,
              // ),
              IconButton(
                tooltip: 'Skanuj',
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ScanScreen())),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
