// lib/screens/audit_log_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AuditLogScreen extends StatelessWidget {
  const AuditLogScreen({super.key});

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
              final d = docs[i].data()! as Map<String, dynamic>;
              final ts = (d['timestamp'] as Timestamp).toDate();
              final when = DateFormat('dd.MM.yyyy HH:mm').format(ts);
              return ListTile(
                leading: Icon(Icons.history_edu, size: 28),
                title: Text(d['action'] ?? '—'),
                subtitle: Text('${d['userName'] ?? d['userId']} • $when'),
                isThreeLine: d['details'] != null,
                trailing: d['details'] != null
                    ? IconButton(
                        icon: Icon(Icons.info_outline),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text('Szczegóły'),
                            content: Text(d['details'].toString()),
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
