// lib/screens/customer_detail_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'project_editor_screen.dart';

class CustomerDetailScreen extends StatefulWidget {
  final String customerId;
  final bool isAdmin;

  const CustomerDetailScreen({
    Key? key,
    required this.customerId,
    required this.isAdmin,
  }) : super(key: key);

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

  Future<void> _editProject(String projectId, Map<String, dynamic> data) async {
    String title = data['title'] as String? ?? '';
    DateTime? startDate = (data['startDate'] as Timestamp?)?.toDate().toLocal();
    DateTime? estimatedEndDate = (data['estimatedEndDate'] as Timestamp?)
        ?.toDate()
        .toLocal();
    String costStr = data['estimatedCost']?.toString() ?? '';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Edytuj projekt'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: TextEditingController(text: title),
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
                            ? 'Oczek. koniec'
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
                  controller: TextEditingController(text: costStr),
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
                final doc = _projectsCol.doc(projectId);
                final updates = <String, dynamic>{};
                updates['title'] = title;
                if (startDate != null) {
                  updates['startDate'] = Timestamp.fromDate(startDate!);
                }
                if (estimatedEndDate != null) {
                  updates['estimatedEndDate'] = Timestamp.fromDate(
                    estimatedEndDate!,
                  );
                }
                final cost = double.tryParse(costStr.replaceAll(',', '.'));
                if (cost != null) updates['estimatedCost'] = cost;
                doc.update(updates);
                Navigator.pop(ctx);
              },
              child: const Text('Zapisz'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          // ListTile(
          //   leading: const Icon(Icons.list_alt_rounded),
          //   title: const Text('Dok. RW/MM'),
          //   onTap: () {
          //     Navigator.of(context).push(
          //       MaterialPageRoute(
          //         builder: (_) =>
          //             RWDocumentsScreen(customerId: widget.customerId),
          //       ),
          //     );
          //   },
          // ),
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
                            isAdmin: widget.isAdmin,
                          ),
                        ),
                      ),

                      trailing: widget.isAdmin
                          ? IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Usuń projekt',
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx2) => AlertDialog(
                                    title: Text('Usuń projekt?'),
                                    content: Text(
                                      'Na pewno usunąć projekt "${data['title']}"?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx2, false),
                                        child: Text('Anuluj'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx2, true),
                                        child: Text('Usuń'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true) {
                                  await _projectsCol.doc(d.id).delete();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Projekt usunięty')),
                                  );
                                }
                              },
                            )
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton(
              onPressed: _addProject,
              child: const Icon(Icons.playlist_add),
            )
          : null,
    );
  }
}
