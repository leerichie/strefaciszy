import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:strefa_ciszy/services/api_service.dart';

class ApprovalScreen extends StatefulWidget {
  const ApprovalScreen({super.key});

  @override
  State<ApprovalScreen> createState() => _ApprovalScreenState();
}

class _ApprovalScreenState extends State<ApprovalScreen> {
  // 🔒 Simple approval gate (adjust the email!)
  bool get _isApproved {
    final email = FirebaseAuth.instance.currentUser?.email?.toLowerCase() ?? '';
    // TODO: change this to your approval person's email
    return email == 'leerichie@wp.pl';
  }

  // Filter range: show recent activity (default 14 days)
  Duration _range = const Duration(days: 14);

  Stream<QuerySnapshot<Map<String, dynamic>>> _projectsStream() {
    final now = DateTime.now();
    final start = now.subtract(_range);

    // Pull recent projects changed via lastRwDate
    // Note: requires Firestore index on collectionGroup('projects') if prompted.
    return FirebaseFirestore.instance
        .collectionGroup('projects')
        // .where('lastRwDate', isGreaterThanOrEqualTo: start)
        // .orderBy('lastRwDate', descending: true)
        .limit(200)
        .snapshots();
  }

  // Cache for customer names (avoid refetching)
  final Map<String, String> _customerNameCache = {};

  Future<String> _getCustomerName(String customerId) async {
    if (_customerNameCache.containsKey(customerId)) {
      return _customerNameCache[customerId]!;
    }
    final snap = await FirebaseFirestore.instance
        .collection('customers')
        .doc(customerId)
        .get();
    final name = snap.data()?['name'] as String? ?? '—';
    _customerNameCache[customerId] = name;
    return name;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isApproved) {
      return Scaffold(
        appBar: AppBar(title: const Text('Potwierdzenia')),
        body: const Center(child: Text('Brak uprawnień.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Potwierdzenia (WAPRO)'),
        actions: [
          PopupMenuButton<Duration>(
            tooltip: 'Zakres',
            onSelected: (d) => setState(() => _range = d),
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: Duration(days: 1), child: Text('Dzisiaj')),
              PopupMenuItem(value: Duration(days: 7), child: Text('7 dni')),
              PopupMenuItem(value: Duration(days: 14), child: Text('14 dni')),
              PopupMenuItem(value: Duration(days: 30), child: Text('30 dni')),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.filter_alt_outlined),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _projectsStream(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Błąd: ${snap.error}'));
          }
          final now = DateTime.now();
          final start = now.subtract(_range);

          final docs = [...(snap.data?.docs ?? [])];

          // keep only projects with items AND lastRwDate >= start
          final filtered = docs.where((d) {
            final data = d.data();
            final items = (data['items'] as List<dynamic>?) ?? const [];
            final ts = data['lastRwDate'] as Timestamp?;
            final dt = ts?.toDate();
            if (items.isEmpty) return false;
            if (dt == null) return false;
            return !dt.isBefore(start);
          }).toList();

          // newest first
          filtered.sort((a, b) {
            final ta = a.data()['lastRwDate'] as Timestamp?;
            final tb = b.data()['lastRwDate'] as Timestamp?;
            final da = ta?.toDate();
            final db = tb?.toDate();
            if (da == null && db == null) return 0;
            if (da == null) return 1;
            if (db == null) return -1;
            return db.compareTo(da);
          });

          final projects = filtered;

          if (projects.isEmpty) {
            return const Center(
              child: Text('Brak projektów do potwierdzenia.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: projects.length,
            itemBuilder: (ctx, i) {
              final p = projects[i];
              final data = p.data();
              final pathSegs = p.reference.path.split(
                '/',
              ); // customers/{cid}/projects/{pid}
              final customerId = pathSegs.length >= 2
                  ? pathSegs[pathSegs.length - 3]
                  : '';
              final projectId = p.id;

              final title = (data['title'] as String?) ?? '—';
              final lastRwDate = (data['lastRwDate'] as Timestamp?)?.toDate();
              final items = (data['items'] as List<dynamic>).cast<Map>();

              return _ProjectCard(
                customerId: customerId,
                projectId: projectId,
                title: title,
                lastRwDate: lastRwDate,
                items: items,
                customerNameFuture: _getCustomerName(customerId),
              );
            },
          );
        },
      ),
    );
  }
}

class _ProjectItemRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ProjectItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final name = (item['name'] as String?) ?? '';
    final producer = (item['producer'] as String?) ?? '';
    final qty = (item['quantity'] as num?)?.toInt() ?? 0;
    final unit = (item['unit'] as String?) ?? '';

    final title = [producer, name].where((e) => e.isNotEmpty).join(' ');
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontSize: 14)),
      trailing: Text(
        '$qty $unit',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ProjectCard extends StatefulWidget {
  final String customerId;
  final String projectId;
  final String title;
  final DateTime? lastRwDate;
  final List<Map> items;
  final Future<String> customerNameFuture;

  const _ProjectCard({
    required this.customerId,
    required this.projectId,
    required this.title,
    required this.lastRwDate,
    required this.items,
    required this.customerNameFuture,
  });

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  // key = index in items, value = selected qty (1..itemQty)
  final Map<int, int> _selectedQty = {};

  int get _selectedCount => _selectedQty.length;

  void _selectAll() {
    setState(() {
      _selectedQty
        ..clear()
        ..addAll({
          for (int i = 0; i < widget.items.length; i++)
            if (((widget.items[i]['quantity'] as num?)?.toInt() ?? 0) > 0)
              i: (widget.items[i]['quantity'] as num).toInt(),
        });
    });
  }

  void _clearSelection() {
    setState(() => _selectedQty.clear());
  }

  void _toggleIndex(int idx, bool checked, int maxQty) {
    setState(() {
      if (checked) {
        _selectedQty[idx] = (_selectedQty[idx] ?? maxQty).clamp(1, maxQty);
      } else {
        _selectedQty.remove(idx);
      }
    });
  }

  void _setQty(int idx, int qty, int maxQty) {
    setState(() {
      if (!_selectedQty.containsKey(idx)) return;
      _selectedQty[idx] = qty.clamp(1, maxQty);
    });
  }

  Future<void> _confirmSelection() async {
    // Build payload preview (no API call yet)
    final lines = <Map<String, dynamic>>[];
    for (final entry in _selectedQty.entries) {
      final i = entry.key;
      final qty = entry.value;
      final m = widget.items[i];

      final itemId = (m['itemId'] as String?) ?? '';
      final name = (m['name'] as String?) ?? '';
      final unit = (m['unit'] as String?) ?? 'szt';
      final producer = (m['producer'] as String?) ?? '';

      lines.add({
        if (itemId.isNotEmpty) 'itemId': itemId,
        'name': name,
        'producer': producer,
        'unit': unit,
        'qty': qty,
      });
    }

    if (lines.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nic nie wybrano')));
      return;
    }

    final titleText = await widget.customerNameFuture
        .then((c) => '$c  •  ${widget.title}')
        .catchError((_) => widget.title);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Potwierdzić wydanie?'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titleText,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              for (final ln in lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '${ln['producer'] ?? ''} ${ln['name']}  —  ${ln['qty']} ${ln['unit']}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                'Projekt: ${widget.projectId}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.verified_outlined),
            label: const Text('Potwierdź'),
            onPressed: () async {
              Navigator.pop(ctx); // close preview

              // Build API payload lines (prefer itemId when present)
              final apiLines = <Map<String, dynamic>>[];
              for (final entry in _selectedQty.entries) {
                final i = entry.key;
                final qty = entry.value;
                final m = widget.items[i];

                final itemId = (m['itemId'] as String?) ?? '';
                final name = (m['name'] as String?) ?? '';
                final unit = (m['unit'] as String?) ?? 'szt';
                final producer = (m['producer'] as String?) ?? '';

                apiLines.add({
                  if (itemId.isNotEmpty) 'itemId': itemId,
                  'qty': qty,
                  'unit': unit,
                  // keep these for logs on the server:
                  'name': name,
                  'producer': producer,
                });
              }

              final email = FirebaseAuth.instance.currentUser?.email ?? '';

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Wysyłam potwierdzenie…')),
              );

              try {
                final resp = await ApiService.commitProjectItems(
                  customerId: widget.customerId,
                  projectId: widget.projectId,
                  items: apiLines,
                  actorEmail: email,
                  dryRun:
                      false, // set true if you want to test without WAPRO writes
                );

                final ok = (resp['ok'] == true) || (resp['success'] == true);
                final doc = (resp['docId'] ?? resp['document'] ?? '')
                    .toString();

                if (ok) {
                  _selectedQty.clear(); // reset selection
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          doc.isNotEmpty
                              ? 'Zatwierdzono. Dokument: $doc'
                              : 'Zatwierdzono.',
                        ),
                      ),
                    );
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Błąd: ${resp.toString()}')),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Błąd wysyłki: $e')));
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 2,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        title: FutureBuilder<String>(
          future: widget.customerNameFuture,
          builder: (ctx, nameSnap) {
            final custName = nameSnap.data ?? 'Klient…';
            return Text(
              '$custName  •  ${widget.title}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            );
          },
        ),
        subtitle: Text(
          widget.lastRwDate != null
              ? 'Ostatnia zmiana: ${widget.lastRwDate!.toLocal()}'
              : 'Ostatnia zmiana: —',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                for (int i = 0; i < widget.items.length; i++)
                  _SelectableItemRow(
                    item: widget.items[i] as Map<String, dynamic>,
                    checked: _selectedQty.containsKey(i),
                    selectedQty: _selectedQty[i] ?? 0,
                    onCheckedChanged: (v, maxQty) => _toggleIndex(i, v, maxQty),
                    onQtyChanged: (q, maxQty) => _setQty(i, q, maxQty),
                  ),

                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.select_all),
                      label: const Text('Zaznacz wszystko'),
                      onPressed: _selectAll,
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.clear),
                      label: const Text('Wyczyść'),
                      onPressed: _clearSelection,
                    ),

                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 160),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.verified_user_outlined),
                          label: Text('Potwierdź (${_selectedCount})'),
                          onPressed: _selectedCount == 0
                              ? null
                              : _confirmSelection,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'ID: ${widget.projectId}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectableItemRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool checked;
  final int selectedQty;
  final void Function(bool checked, int maxQty) onCheckedChanged;
  final void Function(int newQty, int maxQty) onQtyChanged;

  const _SelectableItemRow({
    required this.item,
    required this.checked,
    required this.selectedQty,
    required this.onCheckedChanged,
    required this.onQtyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final name = (item['name'] as String?) ?? '';
    final producer = (item['producer'] as String?) ?? '';
    final unit = (item['unit'] as String?) ?? 'szt';
    final maxQty = (item['quantity'] as num?)?.toInt() ?? 0;

    final title = [producer, name].where((e) => e.isNotEmpty).join(' ');

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Checkbox(
        value: checked,
        onChanged: (v) => onCheckedChanged(v ?? false, maxQty),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      trailing: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (checked) ...[
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: selectedQty > 1
                    ? () => onQtyChanged(selectedQty - 1, maxQty)
                    : null,
              ),
              Text(
                '$selectedQty $unit',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: selectedQty < maxQty
                    ? () => onQtyChanged(selectedQty + 1, maxQty)
                    : null,
              ),
            ] else
              Text(
                '$maxQty $unit',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
          ],
        ),
      ),

      onTap: () => onCheckedChanged(!checked, maxQty),
    );
  }
}
