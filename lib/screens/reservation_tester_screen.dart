import 'dart:async';

import 'package:flutter/material.dart';
import 'package:strefa_ciszy/services/admin_api.dart';
import 'package:strefa_ciszy/services/api_service.dart';

class ReservationTesterScreen extends StatefulWidget {
  const ReservationTesterScreen({super.key});

  @override
  State<ReservationTesterScreen> createState() =>
      _ReservationTesterScreenState();
}

class _ReservationTesterScreenState extends State<ReservationTesterScreen> {
  final _projectCtrl = TextEditingController(text: 'P-100');
  final _itemCtrl = TextEditingController(text: '123');
  final _qtyCtrl = TextEditingController(text: '1');

  String? _reservationId;
  String _log = 'Ready.';

  bool _busy = false;
  void _setBusy(bool v) => setState(() => _busy = v);

  Future<void> _reserve() async {
    try {
      _setBusy(true);
      final rid = await AdminApi.reserve(
        projectId: _projectCtrl.text.trim(),
        idArtykulu: int.parse(_itemCtrl.text.trim()),
        qty: num.parse(_qtyCtrl.text.trim()),
        user: 'tester',
        comment: 'debug',
      );
      setState(() {
        _reservationId = rid.isEmpty ? null : rid;
        _log = 'Reserved. ReservationId=$rid';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reserved OK')));
    } catch (e) {
      setState(() => _log = 'Reserve ERROR: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Reserve failed: $e')));
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _refreshAvail() async {
    final id = int.tryParse(_itemCtrl.text.trim());
    if (id == null) return;
    try {
      final rows = await AdminApi.catalog(q: '', top: 1);
    } catch (_) {}
  }

  Future<void> _confirm() async {
    if (_reservationId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No reservationId yet.')));
      return;
    }
    try {
      _setBusy(true);
      await AdminApi.confirm(reservationId: _reservationId!, lockAll: true);
      setState(() => _log = 'Confirmed for invoice.');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Confirmed OK')));
    } catch (e) {
      setState(() => _log = 'Confirm ERROR: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Confirm failed: $e')));
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _invoiced() async {
    if (_reservationId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No reservationId yet.')));
      return;
    }
    final invoice = await _ask('Invoice number (e.g. FV/2025/001)');
    if (invoice == null || invoice.trim().isEmpty) return;

    try {
      _setBusy(true);
      await AdminApi.invoiced(
        reservationId: _reservationId!,
        invoiceNo: invoice.trim(),
      );
      setState(() => _log = 'Marked invoiced: $invoice');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invoiced: $invoice')));
    } catch (e) {
      setState(() => _log = 'Invoiced ERROR: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invoiced failed: $e')));
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _release() async {
    if (_reservationId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No reservationId yet.')));
      return;
    }
    try {
      _setBusy(true);
      await AdminApi.release(reservationId: _reservationId!);
      setState(() => _log = 'Released (non-invoiced lines).');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Released OK')));
    } catch (e) {
      setState(() => _log = 'Release ERROR: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Release failed: $e')));
    } finally {
      _setBusy(false);
    }
  }

  Future<String?> _ask(String title) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickProduct() async {
    String q = '';
    List<Map<String, dynamic>> results = [];
    bool loading = false;

    await showDialog<void>(
      context: context,
      builder: (_) {
        final ctrl = TextEditingController();
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: const Text('Find product'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: ctrl,
                    decoration: const InputDecoration(
                      labelText: 'Search (name / SKU / barcode)',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (s) async {
                      setState(() {
                        loading = true;
                        q = s.trim();
                      });
                      try {
                        final items = await ApiService.fetchProducts(
                          search: q,
                          limit: 25,
                          offset: 0,
                        );
                        results = items
                            .map(
                              (e) => {
                                'id': e.id,
                                'name': e.name,
                                'sku': e.sku,
                                'barcode': e.barcode,
                                'qty': e.quantity,
                                'unit': e.unit,
                                'producent': e.producent,
                              },
                            )
                            .toList();
                      } catch (_) {
                        results = [];
                      } finally {
                        setState(() {
                          loading = false;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  if (loading) const LinearProgressIndicator(),
                  Flexible(
                    child: results.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: Text(
                              'No results yet. Type and press Enter.',
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: results.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final r = results[i];
                              final title = r['name'] ?? '';
                              final subtitle = [
                                if ((r['sku'] ?? '').toString().isNotEmpty)
                                  'SKU: ${r['sku']}',
                                if ((r['barcode'] ?? '').toString().isNotEmpty)
                                  'EAN: ${r['barcode']}',
                                'Qty: ${r['qty']} ${r['unit'] ?? ''}',
                                if ((r['producent'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                                  r['producent'],
                              ].join(' • ');
                              return ListTile(
                                title: Text(title),
                                subtitle: Text(subtitle),
                                trailing: Text('#${r['id']}'),
                                onTap: () {
                                  _itemCtrl.text = r['id'].toString();
                                  Navigator.pop(ctx);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _projectCtrl.dispose();
    _itemCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final input = InputDecoration(border: const OutlineInputBorder());
    return Scaffold(
      appBar: AppBar(title: const Text('Reservation Tester')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _itemCtrl,
                      decoration: input.copyWith(labelText: 'ID_ARTYKULU'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _pickProduct,
                    icon: const Icon(Icons.search),
                    label: const Text('Find'),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: _reserve,
                    child: const Text('Reserve'),
                  ),
                  FilledButton(
                    onPressed: _confirm,
                    child: const Text('Confirm'),
                  ),
                  FilledButton(
                    onPressed: _invoiced,
                    child: const Text('Invoiced'),
                  ),
                  OutlinedButton(
                    onPressed: _release,
                    child: const Text('Release'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'ReservationId: ${_reservationId ?? '-'}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(child: Text(_log)),
                ),
              ),
              if (_busy) const LinearProgressIndicator(minHeight: 3),
            ],
          ),
        ),
      ),
    );
  }
}
