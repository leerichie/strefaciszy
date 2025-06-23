// lib/widgets/project_history_list.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ProjectHistoryList extends StatelessWidget {
  /// Pass in both customerId & projectId so we can
  /// look up the project title and then filter the logs.
  final String customerId;
  final String projectId;

  const ProjectHistoryList({
    Key? key,
    required this.customerId,
    required this.projectId,
  }) : super(key: key);

  IconData _iconForAction(String action) {
    if (action.startsWith('Utworzono')) return Icons.add_box_outlined;
    if (action.startsWith('Zaktualizowano')) return Icons.edit;
    if (action.startsWith('Usunięto')) return Icons.delete_outline;
    return Icons.history_edu;
  }

  @override
  Widget build(BuildContext context) {
    final usersRef = FirebaseFirestore.instance.collection('users');
    final projRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(customerId)
        .collection('projects')
        .doc(projectId);

    return FutureBuilder<DocumentSnapshot>(
      future: projRef.get(),
      builder: (ctxP, projSnap) {
        if (projSnap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final projData = projSnap.data?.data() as Map<String, dynamic>? ?? {};
        final projectName = projData['title'] as String? ?? '';

        // 1) Load all users (to map uid→displayName)
        return FutureBuilder<QuerySnapshot>(
          future: usersRef.get(),
          builder: (ctxU, userSnap) {
            if (userSnap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final userMap = <String, String>{};
            for (var doc in userSnap.data!.docs) {
              final d = doc.data()! as Map<String, dynamic>;
              userMap[doc.id] = d['name'] as String? ?? doc.id;
            }

            // 2) Stream audit_logs filtered by this project
            final logsQuery = FirebaseFirestore.instance
                .collection('audit_logs')
                .where('details.Projekt', isEqualTo: projectName)
                .orderBy('timestamp', descending: true);

            return StreamBuilder<QuerySnapshot>(
              stream: logsQuery.snapshots(),
              builder: (ctxL, logSnap) {
                if (logSnap.connectionState != ConnectionState.active) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = logSnap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('Brak historii.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final data = docs[i].data()! as Map<String, dynamic>;
                    final action = data['action'] as String? ?? '';
                    final ts = data['timestamp'] as Timestamp?;
                    final when = ts != null
                        ? DateFormat('dd.MM.yyyy • HH:mm').format(ts.toDate())
                        : '';

                    final uid = data['userId'] as String? ?? '';
                    final name = userMap[uid] ?? uid;

                    // split out each material change for a flat list?
                    // for now, just show the entire details.Szczegóły field
                    final details =
                        (data['details'] as Map?)?.cast<String, dynamic>() ??
                        {};
                    final summary = details['Szczegóły'] as String? ?? '';

                    return ListTile(
                      leading: Icon(_iconForAction(action)),
                      title: Text('$name  –  $when'),
                      subtitle: Text(summary),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
