// lib/widgets/project_history_list.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ProjectHistoryList extends StatelessWidget {
  final String customerId;
  final String projectId;

  const ProjectHistoryList({
    Key? key,
    required this.customerId,
    required this.projectId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final logsRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(customerId)
        .collection('projects')
        .doc(projectId)
        .collection('audit_logs')
        .orderBy('timestamp', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: logsRef.snapshots(),
      builder: (ctx, snap) {
        // 1) Handle errors
        if (snap.hasError) {
          return Center(child: Text('Błąd ładowania historii: ${snap.error}'));
        }
        // 2) While waiting or still null, show a spinner
        if (snap.connectionState == ConnectionState.waiting ||
            !snap.hasData ||
            snap.data == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('Brak historii dla tego projektu.'));
        }

        return ListView.separated(
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final d = docs[i].data()! as Map<String, dynamic>;

            // action icon
            final icon = _iconForAction(d['action'] as String);

            // timestamp
            final ts = (d['timestamp'] as Timestamp).toDate();
            final when = DateFormat('dd.MM.yyyy – HH:mm').format(ts);

            // details map
            final details = (d['details'] as Map).cast<String, dynamic>();
            // for example: build a single line from details
            final itemName = details['itemName'] ?? '–';
            final count = details['count']?.toString() ?? '';
            final delta = details['delta'] is num
                ? (details['delta'] as num) >= 0
                      ? '+${details['delta']}'
                      : details['delta'].toString()
                : '';

            return ListTile(
              leading: Icon(icon, size: 20),
              title: Text('${d['userName']}  ·  $when'),
              subtitle: Text('$itemName  ·  $count ($delta)'),
            );
          },
        );
      },
    );
  }

  // you can keep your existing _iconForAction in this file or import it
  IconData _iconForAction(String action) {
    if (action.startsWith('Utworzono')) return Icons.add_box_outlined;
    if (action.startsWith('Zaktualizowano')) return Icons.edit;
    if (action.startsWith('Usunięto')) return Icons.delete_outline;
    return Icons.history_edu;
  }
}
