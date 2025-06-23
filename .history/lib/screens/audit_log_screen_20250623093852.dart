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

  /// Builds a single action row with its details.
  Widget _buildActionRow(BuildContext context, Map<String, dynamic> data) {
    final action = data['action'] as String? ?? '';
    final ts = data['timestamp'] as Timestamp?;
    final when = ts != null
        ? DateFormat('dd.MM.yyyy • HH:mm').format(ts.toDate())
        : '';
    final details = (data['details'] as Map?)?.cast<String, dynamic>() ?? {};

    final detailLines = <Widget>[];
    details.forEach((key, val) {
      detailLines.add(
        Padding(
          padding: const EdgeInsets.only(left: 32, bottom: 2),
          child: Text(
            '$key: $val',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    });

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconForAction(action), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$action: $when',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (detailLines.isNotEmpty) ...[
            const SizedBox(height: 4),
            ...detailLines,
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historia – RW wg. user')),
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
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs
              .map((d) => d.data()! as Map<String, dynamic>)
              .toList();

          if (docs.isEmpty) {
            return const Center(child: Text('Brak wpisów w dzienniku.'));
          }

          final Map<String, List<Map<String, dynamic>>> byUserName = {};
          for (var entry in docs) {
            final name = entry['userName'] as String? ?? '—';
            byUserName.putIfAbsent(name, () => []).add(entry);
          }

          return ListView(
            children: byUser.entries.map((e) {
              final userName = e.key;
              final actions = e.value;
              return ExpansionTile(
                title: Text(
                  userName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                trailing: Text(
                  '${actions.length}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
                children: actions
                    .map((data) => _buildActionRow(context, data))
                    .toList(),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
