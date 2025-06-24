import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AuditLogList extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  final bool showContextLabels;  // ← new

  const AuditLogList({
    Key? key,
    required this.stream,
    this.showContextLabels = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (ctx, snap) { … same as before … }
    );
  }

  Widget _buildHistoryRow(BuildContext c, Map<String, dynamic> log) {
    // pull out everything
    final userName = log['userName'] as String? ?? '…';
    final ts = log['timestamp'] as Timestamp?;
    final when = ts == null
        ? '…'
        : DateFormat('dd.MM.yyyy • HH:mm').format(ts.toDate());
    final details = (log['details'] as Map?)?.cast<String, dynamic>() ?? {};

    // if you’re in project-context and you logged “Klient” & “Projekt” you can drop them here
    final detailWidgets = <Widget>[];
    details.forEach((k, v) {
      if (!showContextLabels && (k == 'Klient' || k == 'Projekt')) return;
      detailWidgets.add(
        Padding(
          padding: const EdgeInsets.only(left: 32, bottom: 2),
          child: Text('$k: $v', style: Theme.of(c).textTheme.bodySmall),
        ),
      );
    });

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
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
                  style: Theme.of(c)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
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
