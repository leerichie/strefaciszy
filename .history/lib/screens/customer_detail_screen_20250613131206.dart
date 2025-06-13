// lib/screens/customer_detail_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'project_editor_screen.dart';

class CustomerDetailScreen extends StatefulWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  _CustomerDetailScreenState createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late final CollectionReference _projectsCol;

  @override
  void initState() {
    super.initState();
    _projectsCol = FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('projects');
  }

  Future<void> _addProject() async {
    String title = '';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('New Project'),
        content: TextField(
          decoration: InputDecoration(labelText: 'Project Title'),
          onChanged: (v) => title = v.trim(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (title.isNotEmpty) {
                Navigator.pop(ctx);
              }
            },
            child: Text('Create'),
          ),
        ],
      ),
    );
    if (title.isEmpty) return;

    // create draft project
    final uid = DateTime.now().millisecondsSinceEpoch.toString();
    final docRef = await _projectsCol.add({
      'title': title,
      'status': 'draft',
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy':
          uid, // replace with FirebaseAuth.instance.currentUser!.uid if you have auth
      'items': <Map<String, dynamic>>[],
    });

    // navigate into the editor
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProjectEditorScreen(
          customerId: widget.customerId,
          projectId: docRef.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Customer Projects')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _projectsCol.orderBy('createdAt', descending: true).snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return Center(child: Text('No projects yet.'));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => Divider(),
            itemBuilder: (ctx, i) {
              final d = docs[i];
              final data = d.data()! as Map<String, dynamic>;
              final status = data['status'] as String? ?? 'draft';
              final ts = data['createdAt'] as Timestamp?;
              final date = ts != null
                  ? ts.toDate().toLocal().toString().split('.')[0]
                  : '';

              return ListTile(
                title: Text(data['title'] ?? '—'),
                subtitle: Text('Status: $status\nCreated: $date'),
                isThreeLine: true,
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
        tooltip: 'New Project',
        child: Icon(Icons.playlist_add),
        onPressed: _addProject,
      ),
    );
  }
}
