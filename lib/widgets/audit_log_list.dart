// lib/widgets/audit_log_list.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AuditLogList extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  final bool showContextLabels;

  const AuditLogList({
    Key? key,
    required this.stream,
    this.showContextLabels = true,
  }) : super(key: key);

  IconData _iconForAction(String action) {
    if (action.startsWith('Utworzono')) return Icons.add_box_outlined;
    if (action.startsWith('Zaktualizowano')) return Icons.edit;
    if (action.startsWith('Usunięto')) return Icons.delete_outline;
    return Icons.history_edu;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (ctx, snap) {
        if (snap.hasError) {
          return Center(child: Text('Błąd ładowania historii: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('Brak wpisów w historii.'));
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
    // 1) pull out userName (or fallback to userId)
    final userName =
        (log['userName'] as String?)
        // if for some reason that’s missing, try userId
        ??
        (log['userId'] as String? ?? '…');

    // 2) action + timestamp
    final action = log['action'] as String? ?? '';
    final ts = log['timestamp'] as Timestamp?;
    final when = ts != null
        ? DateFormat('dd.MM.yyyy • HH:mm').format(ts.toDate())
        : '…';

    // 3) build detail widgets, dropping context labels if desired
    final details = (log['details'] as Map?)?.cast<String, dynamic>() ?? {};
    final detailWidgets = <Widget>[];
    void addLine(String key, String val) {
      detailWidgets.add(
        Padding(
          padding: const EdgeInsets.only(left: 32, bottom: 2),
          child: Text('$key: $val', style: Theme.of(c).textTheme.bodySmall),
        ),
      );
    }

    details.forEach((k, v) {
      if (!showContextLabels && (k == 'Klient' || k == 'Projekt')) return;
      addLine(k, v.toString());
    });

    // 4) render
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconForAction(action), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  // include userName here
                  '$action • $when --- $userName',
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
