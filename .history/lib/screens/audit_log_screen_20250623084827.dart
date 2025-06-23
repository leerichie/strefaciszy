import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AuditLogScreen extends StatelessWidget {
  const AuditLogScreen({Key? key}) : super(key: key);

  IconData _iconForAction(String action) {
    if (action.startsWith('Utworzono')) return Icons.add_box_outlined;
    if (action.startsWith('Zaktualizowano')) return Icons.edit;
    if (action.startsWith('Usunięto')) return Icons.delete_outline;
    return Icons.history_edu;
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBulletList(
    BuildContext context,
    String label,
    String commaSeparated,
  ) {
    final items = commaSeparated
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);
    return [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Text(
          '$label:',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      for (var item in items)
        Padding(
          padding: const EdgeInsets.only(left: 12.0, bottom: 2.0),
          child: Text('• $item', style: Theme.of(context).textTheme.bodyMedium),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historia - RW')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('audit_logs')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.hasError) {
            return Center(
              child: Text('Błąd ładowania dziennika:\n${snap.error}'),
            );
          }
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('Brak wpisów w dzienniku.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final data = docs[i].data()! as Map<String, dynamic>;
              final action = data['action'] as String? ?? '';
              final userName = data['userName'] as String? ?? '';
              final ts = data['timestamp'] as Timestamp?;
              final when = ts != null
                  ? DateFormat('dd.MM.yyyy HH:mm').format(ts.toDate())
                  : '';
              final details =
                  (data['details'] as Map?)?.cast<String, dynamic>() ?? {};

              return ListTile(
                leading: Icon(_iconForAction(action), size: 28),
                title: Text(action),
                subtitle: Text('$userName • $when'),
                trailing: details.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.info_outline),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Szczegóły'),
                            content: SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (details['Klient'] != null)
                                      _buildDetailRow(
                                        context,
                                        'Klient',
                                        details['Klient']!,
                                      ),
                                    if (details['Projekt'] != null)
                                      _buildDetailRow(
                                        context,
                                        'Projekt',
                                        details['Projekt']!,
                                      ),
                                    if (details['Szczegóły'] != null)
                                      ..._buildBulletList(
                                        context,
                                        'Szczegóły',
                                        details['Szczegóły']!,
                                      ),
                                  
                                    ...details.entries
                                        .where(
                                          (e) =>
                                              e.key != 'Klient' &&
                                              e.key != 'Projekt' &&
                                              e.key != 'Szczegóły' &&
                                        )
                                        .map(
                                          (e) => _buildDetailRow(
                                            context,
                                            e.key,
                                            e.value,
                                          ),
                                        ),
                                  ],
                                ),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Zamknij'),
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
