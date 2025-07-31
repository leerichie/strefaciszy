// lib/screens/customer_detail_screen.dart

import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  Future<void> _showProjectDialog({
    required BuildContext context,
    required String customerId,
    String? projectId,
    Map<String, dynamic>? existingData,
  }) async {
    final titleCtrl = TextEditingController(text: existingData?['title'] ?? '');
    final costCtrl = TextEditingController(
      text: existingData?['estimatedCost']?.toString() ?? '',
    );
    DateTime? startDate = existingData?['startDate']?.toDate();
    DateTime? endDate = existingData?['estimatedEndDate']?.toDate();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(projectId == null ? 'Nowy Projekt' : 'Edytuj Projekt'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nazwa projektu',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        startDate == null
                            ? 'Data rozpoczęcia'
                            : DateFormat('dd.MM.yyyy').format(startDate!),
                      ),
                    ),
                    TextButton(
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
                      child: const Text('Wybierz'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        endDate == null
                            ? 'Data zakończenie'
                            : DateFormat('dd.MM.yyyy').format(endDate!),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final dt = await showDatePicker(
                          context: ctx,
                          initialDate: endDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          locale: const Locale('pl', 'PL'),
                        );
                        if (dt != null) setState(() => endDate = dt);
                      },
                      child: const Text('Wybierz'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: costCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Oszacowany koszt',
                    prefixText: 'PLN ',
                  ),
                  keyboardType: TextInputType.number,
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
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) return;
                final data = <String, dynamic>{
                  'title': title,
                  'status': existingData?['status'] ?? 'draft',
                  'customerId': customerId,
                  'createdAt':
                      existingData?['createdAt'] ??
                      FieldValue.serverTimestamp(),
                  'createdBy': FirebaseAuth.instance.currentUser!.uid,
                  if (startDate != null)
                    'startDate': Timestamp.fromDate(startDate!),
                  if (endDate != null)
                    'estimatedEndDate': Timestamp.fromDate(endDate!),
                  if (double.tryParse(costCtrl.text.replaceAll(',', '.')) !=
                      null)
                    'estimatedCost': double.parse(
                      costCtrl.text.replaceAll(',', '.'),
                    ),
                };

                final col = FirebaseFirestore.instance
                    .collection('customers')
                    .doc(customerId)
                    .collection('projects');

                if (projectId == null) {
                  await col.add(data);
                } else {
                  await col.doc(projectId).set(data, SetOptions(merge: true));
                }

                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(projectId == null ? 'Utwórz' : 'Zapisz'),
            ),
          ],
        ),
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
      setState(() => _favProjectIds.remove(projectId));
    } else {
      await favDoc.set({'customerId': widget.customerId, 'title': title});
      setState(() => _favProjectIds.add(projectId));
    }
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
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            _showProjectDialog(context: context, customerId: widget.customerId),
        child: const Icon(Icons.playlist_add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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
                    final title = data['title'] as String? ?? '—';
                    final createdAt = (data['createdAt'] as Timestamp)
                        .toDate()
                        .toLocal();
                    final dateStr = DateFormat(
                      'dd.MM.yyyy • HH:mm',
                      'pl_PL',
                    ).format(createdAt);
                    final isFav = _favProjectIds.contains(d.id);

                    return ListTile(
                      // Tap IN
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProjectEditorScreen(
                            customerId: widget.customerId,
                            projectId: d.id,
                            isAdmin: widget.isAdmin,
                          ),
                        ),
                      ),
                      // Long‑press EDIT
                      onLongPress: widget.isAdmin
                          ? () => _showProjectDialog(
                              context: context,
                              customerId: widget.customerId,
                              projectId: d.id,
                              existingData: data,
                            )
                          : null,

                      title: Text(title),
                      subtitle: Text(dateStr),

                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              isFav ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                            ),
                            tooltip: isFav
                                ? 'Usuń z ulubionych'
                                : 'Dodaj do ulubionych',
                            onPressed: () =>
                                _toggleFavouriteProjects(d.id, title),
                          ),

                          // RW badge
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

                          // delete for admins
                          if (widget.isAdmin) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Usuń projekt',
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx3) => AlertDialog(
                                    title: const Text('Usuń projekt?'),
                                    content: Text(
                                      'Na pewno usunąć projekt "$title"?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx3, false),
                                        child: const Text('Anuluj'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx3, true),
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

      // bottomNavigationBar: BottomAppBar(
      //   elevation: 4,
      //   shape: const CircularNotchedRectangle(),
      //   notchMargin: 6,
      //   child: Padding(
      //     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      //     child: Row(
      //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
      //       children: [
      //         IconButton(
      //           tooltip: 'Contacts',
      //           icon: const Icon(Icons.people),
      //           onPressed: () => Navigator.of(context).push(
      //             MaterialPageRoute(
      //               builder: (_) => ContactsListScreen(
      //                 isAdmin: widget.isAdmin,
      //                 customerId: widget.customerId,
      //               ),
      //             ),
      //           ),
      //         ),

      //         SizedBox(width: 48),

      //         // IconButton(
      //         //   tooltip: 'Edytuj projekty',
      //         //   icon: const Icon(Icons.edit),
      //         //   onPressed: _editProjects,
      //         // ),
      //         IconButton(
      //           tooltip: 'Skanuj',
      //           icon: const Icon(Icons.qr_code_scanner),
      //           onPressed: () => Navigator.of(
      //             context,
      //           ).push(MaterialPageRoute(builder: (_) => const ScanScreen())),
      //         ),
      //       ],
      //     ),
      //   ),
      // ),
    );
  }
}
