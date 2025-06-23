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

  Stream<QuerySnapshot> get _historyStream => FirebaseFirestore.instance
      .collection('customers')
      .doc(customerId)
      .collection('projects')
      .doc(projectId)
      .collection('audit_logs')
      .orderBy('timestamp', descending: true)
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _historyStream,
      builder: (ctx, snap) {
        if (snap.hasError) {
          return Center(child: Text('Błąd ładowania historii: ${snap.error}'));
        }
        if (!snap.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Center(child: Text('Brak historii.'));
        }

        return ListView(
          children: docs.map((d) {
            final log = d.data()! as Map<String, dynamic>;
            return _buildHistoryRow(log);
          }).toList(),
        );
      },
    );
  }

  Widget _buildHistoryRow(Map<String, dynamic> log) {
    final userName = log['userName'] as String? ?? '…';
    final ts = log['timestamp'] as Timestamp?;
    final when = ts != null
        ? DateFormat('dd.MM.yyyy – HH:mm').format(ts.toDate())
        : '…';
    final details = (log['details'] as Map?)?.cast<String, dynamic>() ?? {};

    final itemName = details['item'] as String? ?? '';
    final change = details['change'] as String? ?? '';

    return ListTile(
      leading: Icon(Icons.history_edu, size: 20),
      title: Text('$userName  ·  $when'),
      subtitle: Text('$itemName  ($change)'),
    );
  }
}

//   IconData _iconForAction(String action) {
//     if (action.startsWith('Utworzono')) return Icons.add_box_outlined;
//     if (action.startsWith('Zaktualizowano')) return Icons.edit;
//     if (action.startsWith('Usunięto')) return Icons.delete_outline;
//     return Icons.history_edu;
//   }
// }
