import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:strefa_ciszy/services/admin_api.dart';
import 'package:strefa_ciszy/services/api_service.dart';

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
            title: const Text('Projekty do zatwierdzenie (WF-MAG sync)'),
            actions: [
              IconButton(
                tooltip: 'Szybkie zwolnienie rezerwacji',
                icon: const Icon(Icons.lock_open_outlined),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => QuickReservationResetSheet(
                      actorEmail:
                          FirebaseAuth.instance.currentUser?.email ?? 'app',
                    ),
                  );
                },
              ),
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
                icon: const Icon(Icons.filter_alt_outlined),
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
                  final reservationId = (m['reservationId'] as String?)?.trim();
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
                    reservationId: reservationId,
                  );
                },
              );
            },
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'fab-reset',
            icon: const Icon(Icons.lock_open),
            label: const Text('Reset rezerwacji'),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => QuickReservationResetSheet(
                  actorEmail: FirebaseAuth.instance.currentUser?.email ?? 'app',
                ),
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
  final String? reservationId;

  const _ProjectCard({
    required this.customerId,
    required this.projectId,
    required this.title,
    required this.lastRwDate,
    required this.items,
    required this.customerNameFuture,
    required this.docRef,
    this.reservationId,
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

  bool get _canInvoice {
    if (_selectedQty.isEmpty) return false;
    for (final e in _selectedQty.entries) {
      final maxQty = (_items[e.key]['quantity'] as num?)?.toInt() ?? 0;
      if (e.value > 0 && maxQty > 0) return true;
    }
    return false;
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

  Future<void> _invoiceSelected() async {
    if (!_canInvoice) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nic nie wybrano')));
      return;
    }

    // Build payload for backend: [{ itemId:int, qty:num }]
    final List<Map<String, dynamic>> lines = [];
    _selectedQty.forEach((idx, qty) {
      final m = _items[idx];
      final idStr = (m['itemId'] ?? '').toString();
      final id = int.tryParse(idStr);
      final maxQty = (m['quantity'] as num?)?.toInt() ?? 0;
      final q = qty.clamp(1, maxQty);
      if (id != null && q > 0) {
        lines.add({'itemId': id, 'qty': q});
      }
    });

    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wybrane pozycje nie mają ID lub ilości.'),
        ),
      );
      return;
    }

    // Optional invoice number
    final ctrl = TextEditingController();
    final enteredInvoice = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Twoj numer faktury'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Moze byc pusty nazwa',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Pomiń'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    // Final confirmation
    final proceed = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Oznaczyć jako fakturowany?'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final e in _selectedQty.entries)
                  Builder(
                    builder: (_) {
                      final i = e.key;
                      final q = e.value;
                      final m = _items[i];
                      final name = (m['name'] as String?) ?? '';
                      final prod = (m['producer'] as String?) ?? '';
                      final unit = (m['unit'] as String?) ?? 'szt';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('$prod $name  —  $q $unit'),
                      );
                    },
                  ),
                const SizedBox(height: 8),
                Text(
                  'Projekt: ${widget.projectId}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if ((enteredInvoice ?? '').isNotEmpty)
                  Text(
                    'FV: $enteredInvoice',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Oznacz'),
            ),
          ],
        );
      },
    );
    if (proceed != true) return;

    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Oznaczam fakturowanie…')));

      final tag = await AdminApi.invoicedPartial(
        projectId: widget.projectId,
        lines: lines,
        invoiceNo: (enteredInvoice != null && enteredInvoice.isNotEmpty)
            ? enteredInvoice
            : null,
      );

      setState(() {
        final removeIdx = <int>[];
        _selectedQty.forEach((idx, qty) {
          final maxQty = (_items[idx]['quantity'] as num?)?.toInt() ?? 0;
          final newQty = (maxQty - qty).clamp(0, maxQty);
          _items[idx]['quantity'] = newQty;
          if (newQty == 0) removeIdx.add(idx);
        });
        removeIdx.sort((a, b) => b.compareTo(a));
        for (final i in removeIdx) {
          _items.removeAt(i);
        }
        _selectedQty.clear();
      });

      try {
        await _mirrorProjectAndRwDocs(_items);
      } catch (_) {}

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Oznaczono fakturowanie • $tag')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Błąd: $e')));
    }
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
              ? 'Ostatnia zmiana: ${DateFormat('dd.MM.yyyy HH:mm', 'pl_PL').format(widget.lastRwDate!.toLocal())}'
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
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('Gotowy do fakturowanie?'),
                      onPressed: _canInvoice ? _invoiceSelected : null,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SelectableText(
                      'ID: ${widget.projectId}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 4),
                  ],
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

    final lastInv = item['lastInvoiced'];
    final invoicedQty = (lastInv is Map && lastInv['qty'] is num)
        ? (lastInv['qty'] as num).toInt()
        : 0;
    final invoiceTag =
        (lastInv is Map ? (lastInv['tag'] as String?) : null) ?? '';

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Checkbox(
        value: checked,
        onChanged: (v) => onCheckedChanged(v ?? false, maxQty),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14)),
          if (invoicedQty > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Wrap(
                spacing: 6,
                children: [
                  Chip(
                    label: Text(
                      'Fakturowano: $invoicedQty $unit'
                      '${invoiceTag.isNotEmpty ? ' • $invoiceTag' : ''}',
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
        ],
      ),
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

class QuickReservationResetSheet extends StatefulWidget {
  final String actorEmail;
  const QuickReservationResetSheet({super.key, required this.actorEmail});

  @override
  State<QuickReservationResetSheet> createState() =>
      _QuickReservationResetSheetState();
}

class _QuickReservationResetSheetState
    extends State<QuickReservationResetSheet> {
  final _projectCtrl = TextEditingController();
  final _itemCtrl = TextEditingController();
  bool _busy = false;
  String _error = '';
  Map<String, dynamic>? _prod;
  Map<String, dynamic>? _probe;

  Future<void> _probeState() async {
    setState(() {
      _busy = true;
      _error = '';
      _prod = null;
      _probe = null;
    });
    try {
      final pid = _projectCtrl.text.trim();
      final itemId = _itemCtrl.text.trim();
      if (itemId.isEmpty) {
        throw Exception('Wpisz id_artykulu z WAPRO');
      }

      final p = await ApiService.fetchProduct(itemId);
      _prod = {
        'name': p?.name ?? '',
        'quantity': p?.quantity ?? 0,
        'unit': p?.unit ?? 'szt',
      };

      final probe = await AdminApi.reservationSummary(
        itemId: itemId,
        projectId: pid.isNotEmpty ? pid : null,
      );

      setState(() {
        _probe = (probe is Map<String, dynamic>) ? probe : null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _resetToZero() async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final itemId = _itemCtrl.text.trim();
      final projectId = _projectCtrl.text.trim();

      if (itemId.isEmpty) {
        throw Exception('Wpisz id_artykulu z WAPRO.');
      }

      final reserved = (_probe?['reserved_total'] as num?)?.toDouble() ?? 0.0;
      if (reserved <= 0) {
        throw Exception('Brak rezerwacji dla tego towaru.');
      }

      await AdminApi.resetItemReservations(
        itemId: itemId,
        projectId: projectId.isNotEmpty ? projectId : null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Rezerwacja zwolniona.')));
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  final _nameCtrl = TextEditingController();
  final List<Map<String, dynamic>> _suggestions = [];

  Future<List<Map<String, dynamic>>> _searchByName(String q) async {
    if (q.trim().length < 3) return [];
    try {
      final res = await AdminApi.catalog(q: q.trim(), top: 20);
      if (res.isEmpty) {
        setState(() {
          _error = 'Brak wyników dla „$q”.';
        });
      } else {
        if (_error.isNotEmpty) _error = '';
      }
      return res;
    } catch (e) {
      setState(() {
        _error =
            'Błąd wyszukiwania: ${e is Exception ? e.toString() : "nieznany błąd"}';
      });
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _prod?['name']?.toString() ?? '';
    final qty = _prod?['quantity']?.toString() ?? '';
    final unit =
        _prod?['unit']?.toString() ?? _probe?['unit']?.toString() ?? 'szt';
    final reservedTotal = _probe?['reserved_total']?.toString() ?? '—';
    final availableAfter = _probe?['available_after']?.toString() ?? '—';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Szybka cofanie rezerwacji',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _projectCtrl,
                decoration: const InputDecoration(
                  labelText: 'projectId',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Autocomplete<Map<String, dynamic>>(
                displayStringForOption: (m) =>
                    '${m['nazwa'] ?? ''} • ID=${m['id_artykulu']}',
                optionsBuilder: (TextEditingValue textEditingValue) async {
                  return await _searchByName(textEditingValue.text);
                },
                onSelected: (m) {
                  _itemCtrl.text = m['id_artykulu'].toString();
                  _nameCtrl.text = m['nazwa'] ?? '';
                },
                fieldViewBuilder: (ctx, ctrl, focus, onSubmit) {
                  return TextField(
                    controller: ctrl,
                    focusNode: focus,
                    decoration: const InputDecoration(
                      labelText: 'Szukaj po nazwie',
                      border: OutlineInputBorder(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _itemCtrl,
                decoration: const InputDecoration(
                  labelText: 'WAPRO id_artykulu:',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.search),
                      label: const Text('Podejrzyj'),
                      onPressed: _busy ? null : _probeState,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.lock_open),
                      label: const Text('Cofnij / Reset'),
                      onPressed: _busy ? null : _resetToZero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_busy) const LinearProgressIndicator(),
              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_prod != null || _probe != null) ...[
                const Divider(height: 24),
                _kv('Nazwa', name),
                _kv('Stan (ilość dostępna)', '$qty $unit'),
                _kv('Zarezerwowane (łącznie)', '$reservedTotal $unit'),
                _kv('Dostępne po zwolnieniu', '$availableAfter $unit'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 210,
          child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Expanded(child: Text(v, maxLines: 2, overflow: TextOverflow.ellipsis)),
      ],
    ),
  );
}
