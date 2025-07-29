import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:strefa_ciszy/utils/colour_utils.dart';

class AuditLogList extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  final bool showContextLabels;

  const AuditLogList({
    super.key,
    required this.stream,
    this.showContextLabels = true,
  });

  IconData _iconForAction(String action) {
    if (action.startsWith('Utworzono')) return Icons.add;
    if (action.startsWith('Zaktualizowano')) return Icons.update;
    if (action.startsWith('Usunięto')) return Icons.delete_forever_outlined;
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
    final userName =
        (log['userName'] as String?) ?? (log['userId'] as String? ?? '…');

    final action = log['action'] as String? ?? '';
    final ts = log['timestamp'] as Timestamp?;
    final when = ts != null
        ? DateFormat('dd.MM.yyyy • HH:mm').format(ts.toDate())
        : '…';

    final details = (log['details'] as Map?)?.cast<String, dynamic>() ?? {};
    final detailWidgets = <Widget>[];
    void addLineText(String text) {
      detailWidgets.add(
        Padding(
          padding: const EdgeInsets.only(left: 32, bottom: 2),
          child: Text(text, style: Theme.of(c).textTheme.bodySmall),
        ),
      );
    }

    // merge Produkt + Zmiana into single line if both exist
    if (details.containsKey('Produkt') && details.containsKey('Zmiana')) {
      final prodVal = details['Produkt'].toString();
      final zmVal = details['Zmiana'].toString();
      addLineText('$prodVal    $zmVal');
      details.remove('Produkt');
      details.remove('Zmiana');
    }

    // render remaining detail entries
    details.forEach((k, v) {
      if (!showContextLabels && (k == 'Klient' || k == 'Projekt')) return;
      addLineText('$k: ${v.toString()}');
    });

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Tooltip(
                message: action,
                child: Icon(_iconForAction(action), size: 16),
              ),
              const SizedBox(width: 8),

              Text(
                when,
                style: Theme.of(
                  c,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w400),
              ),
              const SizedBox(width: 16),

              Icon(Icons.person, size: 16, color: Colors.blueGrey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  userName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colourFromString(userName),
                    fontWeight: FontWeight.w400,
                  ),
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
