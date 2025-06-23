// lib/widgets/project_history_list.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:strefa_ciszy/screens/audit_log_screen.dart';

class ProjectHistoryList extends StatelessWidget {
  final String projectId;
  const ProjectHistoryList({Key? key, required this.projectId})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('audit_logs')
        .where('details.Projekt', isEqualTo: projectId)
        .orderBy('timestamp', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (ctx, snap) {
        if (snap.hasError) return Center(child: Text('Błąd: ${snap.error}'));
        if (!snap.hasData) return Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Center(child: Text('Brak historii dla tego projektu.'));
        }
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => Divider(height: 1),
          itemBuilder: (ctx, i) {
            final data = docs[i].data()! as Map<String, dynamic>;
            final action = data['action'] as String? ?? '';
            final ts = (data['timestamp'] as Timestamp).toDate();
            final user = data['userName'] as String? ?? data['userId'];
            final whenDate = DateFormat('dd.MM.yyyy').format(ts);
            final whenTime = DateFormat('HH:mm').format(ts);
            String detailsLine = '';
            final details =
                (data['details'] as Map?)?.cast<String, dynamic>() ?? {};
            if (details.containsKey('Szczegóły')) {
              final items = (details['Szczegóły'] as String)
                  .split(',')
                  .map((s) => s.trim());
              detailsLine = items.first;
            }
            return ListTile(
              leading: Icon(
                AuditLogScreen()._iconForAction(action),
                size: 20,
                color: Colors.grey[700],
              ),
              title: Text(
                '$user – $whenDate – $whenTime',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text('$detailsLine'),
            );
          },
        );
      },
    );
  }
}
