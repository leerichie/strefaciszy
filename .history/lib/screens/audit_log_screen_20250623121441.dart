import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:strefa_ciszy/screens/customer_list_screen.dart';
import 'package:strefa_ciszy/screens/inventory_list_screen.dart';
import 'package:strefa_ciszy/screens/scan_screen.dart';

class AuditLogScreen extends StatelessWidget {
  const AuditLogScreen({Key? key}) : super(key: key);

  IconData _iconForAction(String action) {
    if (action.startsWith('Utworzono')) return Icons.add_box_outlined;
    if (action.startsWith('Zaktualizowano')) return Icons.edit;
    if (action.startsWith('Usunięto')) return Icons.delete_outline;
    return Icons.history_edu;
  }

  Widget _buildActionRow(BuildContext c, Map<String, dynamic> data) {
    final action = data['action'] as String? ?? '';
    final ts = data['timestamp'] as Timestamp?;
    final when = ts != null
        ? DateFormat('dd.MM.yyyy • HH:mm').format(ts.toDate())
        : '';
    final details = (data['details'] as Map?)?.cast<String, dynamic>() ?? {};

    final detailWidgets = <Widget>[];

    void addLine(String key, String val) {
      detailWidgets.add(
        Padding(
          padding: const EdgeInsets.only(left: 32, bottom: 2),
          child: Text('$key: $val', style: Theme.of(c).textTheme.bodySmall),
        ),
      );
    }

    if (details.containsKey('Klient')) addLine('Klient', details['Klient']!);
    if (details.containsKey('Projekt')) addLine('Projekt', details['Projekt']!);

    if (details.containsKey('Szczegóły')) {
      detailWidgets.add(
        Padding(
          padding: const EdgeInsets.only(left: 32, bottom: 2),
          child: Text('Szczegóły:', style: Theme.of(c).textTheme.bodySmall),
        ),
      );
      for (var item
          in (details['Szczegóły'] as String).split(',').map((s) => s.trim())) {
        if (item.isEmpty) continue;
        detailWidgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 48, bottom: 2),
            child: Text('• $item', style: Theme.of(c).textTheme.bodySmall),
          ),
        );
      }
    }

    for (var e in details.entries.where(
      (e) => e.key != 'Klient' && e.key != 'Projekt' && e.key != 'Szczegóły',
    )) {
      addLine(e.key, e.value);
    }

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
                  '$action • $when',
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

  @override
  Widget build(BuildContext context) {
    final usersRef = FirebaseFirestore.instance.collection('users');
    final logsRef = FirebaseFirestore.instance
        .collection('audit_logs')
        .orderBy('timestamp', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Historia RW')),
      body: FutureBuilder<QuerySnapshot>(
        future: usersRef.get(),
        builder: (ctxU, userSnap) {
          if (userSnap.hasError) {
            return Center(
              child: Text('Błąd ładowania użytkowników\n${userSnap.error}'),
            );
          }
          if (!userSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userMap = <String, String>{};
          for (var doc in userSnap.data!.docs) {
            final data = doc.data()! as Map<String, dynamic>;
            userMap[doc.id] = data['name'] as String? ?? doc.id;
          }

          return StreamBuilder<QuerySnapshot>(
            stream: logsRef.snapshots(),
            builder: (ctxL, logSnap) {
              if (logSnap.hasError) {
                return Center(
                  child: Text('Błąd ładowania logów\n${logSnap.error}'),
                );
              }
              if (!logSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final entries = logSnap.data!.docs
                  .map((d) => d.data()! as Map<String, dynamic>)
                  .toList();

              if (entries.isEmpty) {
                return const Center(child: Text('Brak wpisów w dzienniku.'));
              }

              final byUser = <String, List<Map<String, dynamic>>>{};
              for (var e in entries) {
                final uid = e['userId'] as String? ?? e['userName'] as String;
                byUser.putIfAbsent(uid, () => []).add(e);
              }

              return ListView(
                children: byUser.entries.map((grp) {
                  final uid = grp.key;
                  final display = userMap[uid] ?? uid;
                  final actions = grp.value;
                  return ExpansionTile(
                    title: Text(
                      display,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    trailing: Text(
                      '${actions.length}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                    children: actions
                        .map((e) => _buildActionRow(context, e))
                        .toList(),
                  );
                }).toList(),
              );
            },
          );
        },
      ),
      floatingActionButton: !kIsWeb
          ? FloatingActionButton(
              tooltip: 'Skanuj',
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ScanScreen())),
              child: const Icon(Icons.qr_code_scanner, size: 32),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: SafeArea(
        child: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 6,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: 'Inwentaryzacja',
                  icon: const Icon(Icons.inventory_2),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => InventoryListScreen(isAdmin: true),
                    ),
                  ),
                ),

                IconButton(
                  tooltip: 'Klienci',
                  icon: const Icon(Icons.group),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CustomerListScreen(isAdmin: true),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
