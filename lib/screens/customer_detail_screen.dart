// lib/screens/customer_detail_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:strefa_ciszy/screens/customer_list_screen.dart';
import 'package:strefa_ciszy/screens/inventory_list_screen.dart';
import 'package:strefa_ciszy/screens/scan_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _customerRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId);
    _projectsCol = _customerRef.collection('projects');
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
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

  Future<void> _addProject() async {
    String title = '';
    DateTime? startDate;
    DateTime? estimatedEndDate;
    String costStr = '';

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

  // Future<void> _editProject(String projectId, Map<String, dynamic> data) async {
  //   String title = data['title'] as String? ?? '';
  //   DateTime? startDate = (data['startDate'] as Timestamp?)?.toDate().toLocal();
  //   DateTime? estimatedEndDate = (data['estimatedEndDate'] as Timestamp?)
  //       ?.toDate()
  //       .toLocal();
  //   String costStr = data['estimatedCost']?.toString() ?? '';

  //   await showDialog<void>(
  //     context: context,
  //     builder: (ctx) => StatefulBuilder(
  //       builder: (ctx, setState) => AlertDialog(
  //         title: const Text('Edytuj projekt'),
  //         content: SingleChildScrollView(
  //           child: Column(
  //             mainAxisSize: MainAxisSize.min,
  //             children: [
  //               TextField(
  //                 controller: TextEditingController(text: title),
  //                 decoration: const InputDecoration(
  //                   labelText: 'Nazwa projektu',
  //                 ),
  //                 onChanged: (v) => title = v.trim(),
  //               ),
  //               const SizedBox(height: 8),
  //               Row(
  //                 children: [
  //                   Expanded(
  //                     child: Text(
  //                       startDate == null
  //                           ? 'Start'
  //                           : DateFormat(
  //                               'dd.MM.yyyy',
  //                               'pl_PL',
  //                             ).format(startDate!),
  //                     ),
  //                   ),
  //                   TextButton(
  //                     child: const Text('Wybieraj'),
  //                     onPressed: () async {
  //                       final dt = await showDatePicker(
  //                         context: ctx,
  //                         initialDate: startDate ?? DateTime.now(),
  //                         firstDate: DateTime(2000),
  //                         lastDate: DateTime(2100),
  //                         locale: const Locale('pl', 'PL'),
  //                       );
  //                       if (dt != null) setState(() => startDate = dt);
  //                     },
  //                   ),
  //                 ],
  //               ),
  //               const SizedBox(height: 8),
  //               Row(
  //                 children: [
  //                   Expanded(
  //                     child: Text(
  //                       estimatedEndDate == null
  //                           ? 'Oczek. koniec'
  //                           : DateFormat(
  //                               'dd.MM.yyyy',
  //                               'pl_PL',
  //                             ).format(estimatedEndDate!),
  //                     ),
  //                   ),
  //                   TextButton(
  //                     child: const Text('Wybieraj'),
  //                     onPressed: () async {
  //                       final dt = await showDatePicker(
  //                         context: ctx,
  //                         initialDate: estimatedEndDate ?? DateTime.now(),
  //                         firstDate: DateTime(2000),
  //                         lastDate: DateTime(2100),
  //                         locale: const Locale('pl', 'PL'),
  //                       );
  //                       if (dt != null) setState(() => estimatedEndDate = dt);
  //                     },
  //                   ),
  //                 ],
  //               ),
  //               const SizedBox(height: 8),
  //               TextField(
  //                 controller: TextEditingController(text: costStr),
  //                 decoration: const InputDecoration(labelText: 'Oszac. koszt'),
  //                 keyboardType: TextInputType.number,
  //                 onChanged: (v) => costStr = v.trim(),
  //               ),
  //             ],
  //           ),
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.pop(ctx),
  //             child: const Text('Anuluj'),
  //           ),
  //           ElevatedButton(
  //             onPressed: () {
  //               if (title.isEmpty) return;
  //               final doc = _projectsCol.doc(projectId);
  //               final updates = <String, dynamic>{};
  //               updates['title'] = title;
  //               if (startDate != null) {
  //                 updates['startDate'] = Timestamp.fromDate(startDate!);
  //               }
  //               if (estimatedEndDate != null) {
  //                 updates['estimatedEndDate'] = Timestamp.fromDate(
  //                   estimatedEndDate!,
  //                 );
  //               }
  //               final cost = double.tryParse(costStr.replaceAll(',', '.'));
  //               if (cost != null) updates['estimatedCost'] = cost;
  //               doc.update(updates);
  //               Navigator.pop(ctx);
  //             },
  //             child: const Text('Zapisz'),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<DocumentSnapshot>(
          future: _customerRef.get(),
          builder: (ctx, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Text('…');
            }
            final data = snap.data?.data() as Map<String, dynamic>?;
            final name = data?['name'] as String? ?? '';
            return Text('$name – projekty');
          },
        ),
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
      ),

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
                      title: Text(data['title'] ?? '—'),
                      subtitle: Text('Status: ${data['status']}'),
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
                tooltip: 'Inwentaryzacja',
                icon: const Icon(Icons.inventory_2),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => InventoryListScreen(isAdmin: isAdmin),
                  ),
                ),
              ),

              SizedBox(width: 48),

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
