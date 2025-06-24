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
            return _buildHistoryRow(context, log);
          }).toList(),
        );
      },
    );
  }

  Widget _buildHistoryRow(BuildContext c, Map<String, dynamic> log) {
    // 1) who & when
    final userName = log['userName'] as String? ?? '…';
    final ts = log['timestamp'] as Timestamp?;
    final when = ts != null
        ? DateFormat('dd.MM.yyyy • HH:mm').format(ts.toDate())
        : '…';

    // 2) grab _all_ details
    final details = (log['details'] as Map?)?.cast<String, dynamic>() ?? {};

    // 3) build a list of small Text widgets, one per detail entry
    final detailWidgets = <Widget>[];
    details.forEach((key, val) {
      detailWidgets.add(
        Padding(
          padding: const EdgeInsets.only(left: 32, bottom: 2),
          child: Text('$key: $val', style: Theme.of(c).textTheme.bodySmall),
        ),
      );
    });

    // 4) assemble the row
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_edu, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$userName • $when',
                  style: Theme.of(
                    c,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (detailWidgets.isNotEmpty) ...[
            const SizedBox(height: 4),
            ...detailWidgets,
          ],
        ],
      ),
    );
  }
}
