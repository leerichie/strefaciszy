// lib/screens/customer_detail_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'project_editor_screen.dart';

class CustomerDetailScreen extends StatefulWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  _CustomerDetailScreenState createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late final DocumentReference _customerRef;
  late final CollectionReference _projectsCol;

  @override
  void initState() {
    super.initState();
    _customerRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId);
    _projectsCol = _customerRef.collection('projects');
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
          title: Text('New Project'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(labelText: 'Project Title'),
                  onChanged: (v) => title = v.trim(),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        startDate == null
                            ? 'Start Date'
                            : DateFormat(
                                'dd.MM.yyyy',
                                'pl_PL',
                              ).format(startDate!),
                      ),
                    ),
                    TextButton(
                      child: Text('Select'),
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
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        estimatedEndDate == null
                            ? 'Estimated End Date'
                            : DateFormat(
                                'dd.MM.yyyy',
                                'pl_PL',
                              ).format(estimatedEndDate!),
                      ),
                    ),
                    TextButton(
                      child: Text('Select'),
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
                SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(labelText: 'Estimated Cost'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => costStr = v.trim(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (title.isEmpty) return;
                final data = {
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
              child: Text('Create'),
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
          title: Text('Edit Project'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: TextEditingController(text: title),
                  decoration: InputDecoration(labelText: 'Project Title'),
                  onChanged: (v) => title = v.trim(),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        startDate == null
                            ? 'Start Date'
                            : DateFormat(
                                'dd.MM.yyyy',
                                'pl_PL',
                              ).format(startDate!),
                      ),
                    ),
                    TextButton(
                      child: Text('Select'),
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
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        estimatedEndDate == null
                            ? 'Estimated End Date'
                            : DateFormat(
                                'dd.MM.yyyy',
                                'pl_PL',
                              ).format(estimatedEndDate!),
                      ),
                    ),
                    TextButton(
                      child: Text('Select'),
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
                SizedBox(height: 8),
                TextField(
                  controller: TextEditingController(text: costStr),
                  decoration: InputDecoration(labelText: 'Estimated Cost'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => costStr = v.trim(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (title.isEmpty) return;
                final doc = _projectsCol.doc(projectId);
                final updates = {
                  'title': title,
                  if (startDate != null)
                    'startDate': Timestamp.fromDate(startDate!),
                  if (estimatedEndDate != null)
                    'estimatedEndDate': Timestamp.fromDate(estimatedEndDate!),
                };
                final cost = double.tryParse(costStr.replaceAll(',', '.'));
                if (cost != null) updates['estimatedCost'] = cost;
                doc.update(updates);
                Navigator.pop(ctx);
              },
              child: Text('Save'),
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
            if (snap.connectionState != ConnectionState.done)
              return Text('...');
            final data = snap.data?.data() as Map<String, dynamic>?;
            final name = data?['name'] as String? ?? '';
            return Text('$name Projects');
          },
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _projectsCol.orderBy('createdAt', descending: true).snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          final docs = snap.data!.docs;
          if (docs.isEmpty) return Center(child: Text('No projects yet.'));
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => Divider(),
            itemBuilder: (ctx, i) {
              final d = docs[i];
              final data = d.data()! as Map<String, dynamic>;
              final status = data['status'] as String? ?? 'draft';
              final ts = data['createdAt'] as Timestamp?;
              final startTs = data['startDate'] as Timestamp?;
              final endTs = data['estimatedEndDate'] as Timestamp?;
              final cost = data['estimatedCost'] as num?;
              final created = ts != null
                  ? DateFormat(
                      'dd.MM.yyyy HH:mm',
                      'pl_PL',
                    ).format(ts.toDate().toLocal())
                  : '';
              final start = startTs != null
                  ? DateFormat(
                      'dd.MM.yyyy',
                      'pl_PL',
                    ).format(startTs.toDate().toLocal())
                  : '';
              final end = endTs != null
                  ? DateFormat(
                      'dd.MM.yyyy',
                      'pl_PL',
                    ).format(endTs.toDate().toLocal())
                  : '';
              final costStr = cost != null
                  ? '${cost.toStringAsFixed(2)} zł'
                  : '';
              final lines = <String>[
                'Status: $status',
                if (start.isNotEmpty) 'Start: $start',
                if (end.isNotEmpty) 'End: $end',
                if (costStr.isNotEmpty) 'Cost: $costStr',
                if (created.isNotEmpty) 'Created: $created',
              ];
              return ListTile(
                title: Text(data['title'] ?? '—'),
                subtitle: Text(lines.join('\n')),
                isThreeLine: true,
                trailing: IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () => _editProject(d.id, data),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProjectEditorScreen(
                      customerId: widget.customerId,
                      projectId: d.id,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addProject,
        child: Icon(Icons.playlist_add),
      ),
    );
  }
}
