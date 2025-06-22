// lib/screens/audit_log_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AuditLogScreen extends StatelessWidget {
  const AuditLogScreen({super.key});

  IconData _iconForAction(String action) {
    if (action.startsWith('Utworzono')) return Icons.add_box_outlined;
    if (action.startsWith('Zaktualizowano')) return Icons.edit;
    if (action.startsWith('Usunięto')) return Icons.delete_outline;
    return Icons.history_edu;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Dziennik audytu')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('audit_logs')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.hasError) {
            debugPrint('🔥 Audit load error: ${snap.error}');
            return Center(
              child: Text('Błąd ładowania dziennika:\n${snap.error}'),
            );
          }

          if (!snap.hasData) return Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty)
            return Center(child: Text('Brak wpisów w dzienniku.'));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final data = docs[i].data()! as Map<String, dynamic>;
              final action = data['action'] as String? ?? '—';
              final userName =
                  data['userName'] as String? ?? data['userId'] as String;
              final tsRaw = data['timestamp'] as Timestamp?;
              final when = tsRaw != null
                  ? DateFormat('dd.MM.yyyy HH:mm').format(tsRaw.toDate())
                  : '—';

              // details stored as Map<String,String> in Firestore
              final details = (data['details'] as Map?)?.cast<String, String>();

              return ListTile(
                leading: Icon(_iconForAction(action), size: 28),
                title: Text(action),
                subtitle: Text('$userName • $when'),
                isThreeLine: details != null,
                trailing: details != null
                    ? IconButton(
                        icon: Icon(Icons.info_outline),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text('Szczegóły'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: details.entries
                                  .map(
                                    (e) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                      ),
                                      child: RichText(
                                        text: TextSpan(
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                          children: [
                                            TextSpan(
                                              text: '${e.key}: ',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            TextSpan(text: e.value.toString()),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Zamknij'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
