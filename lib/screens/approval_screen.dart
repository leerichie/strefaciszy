import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:strefa_ciszy/services/admin_api.dart';
import 'package:strefa_ciszy/services/api_service.dart';
import 'package:strefa_ciszy/services/audit_service.dart';

class ApprovalScreen extends StatefulWidget {
  const ApprovalScreen({super.key});

  @override
  State<ApprovalScreen> createState() => _ApprovalScreenState();
}

class _ApprovalScreenState extends State<ApprovalScreen> {
  Duration _range = const Duration(days: 30);

  Stream<QuerySnapshot<Map<String, dynamic>>> _projectsStream() {
    return FirebaseFirestore.instance
        .collectionGroup('projects')
        .limit(200)
        .snapshots();
  }

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
    final email = FirebaseAuth.instance.currentUser?.email?.toLowerCase() ?? '';

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('config')
          .doc('security')
          .snapshots(),
      builder: (context, allowSnap) {
        if (allowSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = allowSnap.data?.data() ?? const <String, dynamic>{};
        final list = List<String>.from(
          data['approverEmails'] ?? const [],
        ).map((e) => e.toLowerCase()).toList();
        final allowed = list.contains(email);

        if (!allowed) {
          return Scaffold(
            appBar: AppBar(title: const Text('Potwierdzenia')),
            body: const Center(
              child: Text('Brak uprawnień (firestore.console).'),
            ),
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
                  PopupMenuItem(
                    value: Duration(days: 1),
                    child: Text('Dzisiaj'),
                  ),
                  PopupMenuItem(value: Duration(days: 7), child: Text('7 dni')),
                  PopupMenuItem(
                    value: Duration(days: 14),
                    child: Text('14 dni'),
                  ),
                  PopupMenuItem(
                    value: Duration(days: 30),
                    child: Text('30 dni'),
                  ),
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

              final filtered = docs.where((d) {
                final m = d.data();
                final items = (m['items'] as List<dynamic>?) ?? const [];
                final ts = m['lastRwDate'] as Timestamp?;
                final dt = ts?.toDate();
                if (items.isEmpty) return false;
                if (dt == null) return false;
                return !dt.isBefore(start);
              }).toList();

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

              if (filtered.isEmpty) {
                return const Center(
                  child: Text('Brak projektów do potwierdzenia.'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final p = filtered[i];
                  final m = p.data();
                  final segs = p.reference.path.split('/');
                  final customerId = segs.length >= 3
                      ? segs[segs.length - 3]
                      : '';
                  final projectId = p.id;

                  final title = (m['title'] as String?) ?? '—';
                  final lastRwDate = (m['lastRwDate'] as Timestamp?)?.toDate();
                  final items = (m['items'] as List<dynamic>).cast<Map>();

                  return _ProjectCard(
                    customerId: customerId,
                    projectId: projectId,
                    title: title,
                    lastRwDate: lastRwDate,
                    items: items,
                    customerNameFuture: _getCustomerName(customerId),
                    docRef: p.reference,
                  );
                },
              );
            },
          ),
        );
      },
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
  final DocumentReference<Map<String, dynamic>> docRef;

  const _ProjectCard({
    required this.customerId,
    required this.projectId,
    required this.title,
    required this.lastRwDate,
    required this.items,
    required this.customerNameFuture,
    required this.docRef,
  });

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  final Map<int, int> _selectedQty = {};
  late List<Map<String, dynamic>> _items;

  int get _selectedCount => _selectedQty.length;

  @override
  void initState() {
    super.initState();
    _items = widget.items.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  DocumentReference<Map<String, dynamic>> get _projRef => widget.docRef;

  Future<DocumentReference<Map<String, dynamic>>?> _findTodayRwDoc() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    final snap = await _projRef
        .collection('rw_documents')
        .where('type', isEqualTo: 'RW')
        .where('createdAt', isGreaterThanOrEqualTo: start)
        .where('createdAt', isLessThan: end)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return snap.docs.first.reference;
  }

  Future<void> _mirrorProjectAndRwDocs(
    List<Map<String, dynamic>> newItems,
  ) async {
    await _projRef.update({
      'items': newItems,
      'lastRwDate': FieldValue.serverTimestamp(),
    });

    final rwRef = await _findTodayRwDoc();
    if (rwRef == null) return;

    if (newItems.isEmpty) {
      await rwRef.delete();
    } else {
      await rwRef.update({
        'items': newItems,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  void _selectAll() {
    setState(() {
      _selectedQty
        ..clear()
        ..addAll({
          for (int i = 0; i < _items.length; i++)
            if (((_items[i]['quantity'] as num?)?.toInt() ?? 0) > 0)
              i: (_items[i]['quantity'] as num).toInt(),
        });
    });
  }

  void _clearSelection() => setState(() => _selectedQty.clear());

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

  Future<void> _releaseSelection() async {
    if (_selectedQty.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nic nie wybrano')));
      return;
    }

    final email = FirebaseAuth.instance.currentUser?.email ?? 'app';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Cofam rezerwacja…')));

    int ok = 0, fail = 0;
    final newQtyByIndex = <int, int>{};

    for (final entry in _selectedQty.entries) {
      final i = entry.key;
      final releaseQty = entry.value;
      final m = _items[i];

      final itemId = (m['itemId'] as String?)?.trim() ?? '';
      final origQty = (m['quantity'] as num?)?.toInt() ?? 0;
      if (itemId.isEmpty || origQty <= 0) continue;

      final newQty = (origQty - releaseQty).clamp(0, origQty);

      try {
        await AdminApi.reserveUpsert(
          projectId: widget.projectId,
          customerId: widget.customerId,
          itemId: itemId,
          qty: newQty,
          warehouseId: null,
          actorEmail: email,
        );
        newQtyByIndex[i] = newQty;
        ok++;
        await _logRelease(m: m, releasedQty: releaseQty, newQty: newQty);
      } catch (_) {
        fail++;
      }
    }

    setState(() {
      final toRemove = <int>[];
      newQtyByIndex.forEach((i, q) {
        if (q == 0) {
          toRemove.add(i);
        } else {
          _items[i]['quantity'] = q;
        }
      });
      toRemove.sort((a, b) => b.compareTo(a));
      for (final idx in toRemove) {
        _items.removeAt(idx);
      }
      _selectedQty.clear();
    });

    try {
      await _mirrorProjectAndRwDocs(_items);
    } catch (_) {}

    if (!mounted) return;
    if (fail == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cofnieta rezerwacja: $ok')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Zwolniono: $ok, błędy: $fail')));
    }
  }

  Future<void> _releaseAllInProject() async {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'app';

    final itemIds = <String>[
      for (final m in _items)
        if ((m['itemId'] as String?)?.isNotEmpty == true)
          (m['itemId'] as String),
    ];
    if (itemIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Projekt nie ma pozycji z ID.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cofac wszystkie rezerwacji?'),
        content: Text(
          'Projekt: ${widget.projectId}\nPozycji: ${itemIds.length}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Zwolnij'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    int ok = 0, fail = 0;
    for (int i = 0; i < _items.length; i++) {
      final m = _items[i];
      final id = (m['itemId'] as String?) ?? '';
      if (id.isEmpty) continue;

      final released = (m['quantity'] as num?)?.toInt() ?? 0;

      try {
        await AdminApi.reserveUpsert(
          projectId: widget.projectId,
          customerId: widget.customerId,
          itemId: id,
          qty: 0,
          warehouseId: null,
          actorEmail: email,
        );
        ok++;

        await _logRelease(m: m, releasedQty: released, newQty: 0);
      } catch (_) {
        fail++;
      }
    }

    setState(() {
      _items.clear();
      _selectedQty.clear();
    });
    await _mirrorProjectAndRwDocs(_items);

    if (_items.isEmpty) {
      await AuditService.logAction(
        action: 'Zwolniono wszystkie rezerwacji',
        customerId: widget.customerId,
        projectId: widget.projectId,
        details: {'Pozycje': '${itemIds.length}', 'RW': 'usuniety (pusty)'},
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Zwolniono: $ok, błędy: $fail')));
  }

  Future<void> _logRelease({
    required Map<String, dynamic> m,
    required int releasedQty,
    required int newQty,
  }) async {
    final unit = (m['unit'] as String?) ?? 'szt';
    final prod = (m['producer'] as String?) ?? '';
    final name = (m['name'] as String?) ?? '';
    final line = [
      prod,
      name,
      '-$releasedQty$unit',
    ].where((x) => x.isNotEmpty).join(' ');

    await AuditService.logAction(
      action: 'Zwolniono rezerwacja',
      customerId: widget.customerId,
      projectId: widget.projectId,
      details: {'•': line, 'Pozostał w projekcie': '$newQty $unit'},
    );
  }

  Future<void> _confirmSelection() async {
    final lines = <Map<String, dynamic>>[];
    for (final entry in _selectedQty.entries) {
      final i = entry.key;
      final qty = entry.value;
      final m = _items[i];

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
        title: const Text('Aktualizować baza Wf-Mag?'),
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
              Navigator.pop(ctx);

              final email = FirebaseAuth.instance.currentUser?.email ?? '';
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Trwa potwierdzenie…')),
              );

              try {
                final resp = await ApiService.commitProjectItems(
                  customerId: widget.customerId,
                  projectId: widget.projectId,
                  items: lines,
                  actorEmail: email,
                  dryRun: false,
                );

                final ok = (resp['ok'] == true) || (resp['success'] == true);
                final doc = (resp['docId'] ?? resp['document'] ?? '')
                    .toString();

                if (ok) {
                  _selectedQty.clear();
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
                  ).showSnackBar(SnackBar(content: Text('Błąd: $e')));
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
                for (int i = 0; i < _items.length; i++)
                  _SelectableItemRow(
                    item: _items[i],
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
                    ElevatedButton.icon(
                      icon: const Icon(Icons.lock_open),
                      label: const Text('Cofnij rezerwacja'),
                      onPressed: _selectedCount == 0 ? null : _releaseSelection,
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.playlist_remove),
                      label: const Text('Cofnij wszystkie'),
                      onPressed: _items.isEmpty ? null : _releaseAllInProject,
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 160),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.verified_user_outlined),
                          label: Text('Potwierdź ($_selectedCount)'),
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
