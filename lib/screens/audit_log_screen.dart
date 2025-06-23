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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Historia - RW')),
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
          if (!snap.hasData) return Center(child: CircularProgressIndicator());

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return Center(child: Text('Brak wpisów w dzienniku.'));
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
                        icon: Icon(Icons.info_outline),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text('Szczegóły'),
                            content: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (details['Klient'] != null)
                                    Padding(
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
                                              text: 'Klient: ',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            TextSpan(text: details['Klient']!),
                                          ],
                                        ),
                                      ),
                                    ),
                                  if (details['Projekt'] != null)
                                    Padding(
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
                                              text: 'Projekt: ',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            TextSpan(text: details['Projekt']!),
                                          ],
                                        ),
                                      ),
                                    ),
                                  if (details['Szczegóły'] != null)
                                    Padding(
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
                                              text: 'Szczegóły: ',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            TextSpan(
                                              text: details['Szczegóły']!,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  if (details['Pozycji'] != null)
                                    Padding(
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
                                              text: 'Pozycji: ',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            TextSpan(text: details['Pozycji']!),
                                          ],
                                        ),
                                      ),
                                    ),
                                  if (details['RW ID'] != null)
                                    Padding(
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
                                              text: 'RW ID: ',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            TextSpan(text: details['RW ID']!),
                                          ],
                                        ),
                                      ),
                                    ),
                                  // any remaining keys:
                                  ...details.entries
                                      .where(
                                        (e) =>
                                            e.key != 'Klient' &&
                                            e.key != 'Projekt' &&
                                            e.key != 'Szczegóły' &&
                                            e.key != 'Pozycji' &&
                                            e.key != 'RW ID',
                                      )
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
                                                TextSpan(text: e.value),
                                              ],
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ],
                              ),
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
