// lib/screens/swap_workflow_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:strefa_ciszy/screens/scan_screen.dart';
import 'package:strefa_ciszy/services/stock_service.dart';

class SwapWorkflowScreen extends StatefulWidget {
  final String customerId;
  final String projectId;
  final bool isAdmin;

  const SwapWorkflowScreen({
    super.key,
    required this.customerId,
    required this.projectId,
    required this.isAdmin,
  });

  @override
  State<SwapWorkflowScreen> createState() => _SwapWorkflowScreenState();
}

class _SwapWorkflowScreenState extends State<SwapWorkflowScreen> {
  String? _oldItemId;
  int _oldQty = 1;
  Map<String, dynamic>? _oldLine;

  String? _newItemId;
  int _newQty = 1;
  Map<String, dynamic>? _newLine;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startOldScan();
    });
  }

  void _startOldScan() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScanScreen(
          returnCode: true,
          titleText: 'Skanuj zwracany produkt',
          onScanned: _onOldScanned,
        ),
      ),
    );
  }

  Future<void> _onOldScanned(String code) async {
    final entry = await StockService.findLatestRwEntryForInput(
      widget.customerId,
      widget.projectId,
      code,
    );

    if (entry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie znaleziono instalacji dla "$code"')),
      );
      _startOldScan();
      return;
    }

    final doc = entry['rwDoc'] as DocumentSnapshot<Map<String, dynamic>>;
    final line = Map<String, dynamic>.from(entry['matchedLine'] as Map);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Czy chcesz zmienic:'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // if (line['producent'] != null)
            Text(
              '${line['producent']} ${line['name'] ?? '–'} ${line['quantity'] ?? '–'} ${line['unit']}',
            ),
            // Text('${line['name'] ?? '–'}'),
            // if (line['unit'] != null)
            // Text(
            //   'Ilość w tej instalacji: ${line['quantity'] ?? '–'} ${line['unit']}',
            // ),
            // if (line['producent'] != null)
            //   Text('Producent: ${line['producent']}'),
            // if (line['unit'] != null) Text('Jednostka: ${line['unit']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Skanuj ponownie'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Akceptuj'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      _startOldScan();
      return;
    }

    setState(() {
      _oldItemId = line['itemId'] as String?;
      _oldLine = line;
      _oldQty = (line['quantity'] as num?)?.toInt() ?? 1;
    });

    _startNewScan();
  }

  void _startNewScan() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScanScreen(
          returnCode: true,
          purpose: ScanPurpose.search,
          titleText: 'Skanuj nowy produkt',
          onScanned: _onNewScanned,
        ),
      ),
    );
  }

  Future<void> _onNewScanned(String code) async {
    final candidates = await StockService.searchStockItems(code);
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie znaleziono produktu dla "$code"')),
      );
      return;
    }

    String chosenId;
    Map<String, dynamic> chosenData;

    if (candidates.length == 1) {
      chosenId = candidates.first.id;
      chosenData = Map<String, dynamic>.from(candidates.first.data());
    } else {
      // user pick
      final pick = await showModalBottomSheet<String?>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Wybierz produkt',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ...candidates.map((doc) {
                final d = doc.data();
                final name = d['name'] ?? '';
                final producent = d['producent'] ?? '';
                final sku = d['sku'] ?? '';
                return ListTile(
                  title: Text('$name'),
                  subtitle: Text('$producent • $sku'),
                  onTap: () => Navigator.pop(ctx, doc.id),
                );
              }),
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Anuluj'),
              ),
            ],
          ),
        ),
      );
      if (pick == null) return;
      chosenId = pick;
      final pickedDoc = candidates.firstWhere((d) => d.id == pick);
      chosenData = Map<String, dynamic>.from(pickedDoc.data());
    }

    try {
      final stock = await StockService.lookupItemDetails(chosenId);
      setState(() {
        _newItemId = chosenId;
        _newLine = stock;
        _newQty = 1;
      });
    } catch (e) {
      setState(() {
        _newItemId = chosenId;
        _newLine = {
          'itemId': chosenId,
          'name': chosenData['name'] ?? '',
          'unit': chosenData['unit'] ?? '',
          'description': chosenData['description'] ?? '',
          'producent': chosenData['producent'] ?? '',
        };
        _newQty = 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bothReady = _oldLine != null && _newLine != null;

    return Scaffold(
      appBar: AppBar(title: Text(bothReady ? 'Potwierdź swap' : 'Swap Mode')),
      body: bothReady
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildLineEditor(
                    'Zwracasz',
                    _oldLine!,
                    _oldQty,
                    (q) => setState(() => _oldQty = q),
                  ),
                  const SizedBox(height: 24),
                  _buildLineEditor(
                    'Instalujesz',
                    _newLine!,
                    _newQty,
                    (q) => setState(() => _newQty = q),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _confirmSwap,
                    child: const Text('Potwierdź swap'),
                  ),
                ],
              ),
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _oldLine == null
                      ? 'Skanuj zwracany produkt'
                      : 'Skanuj nowy produkt',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
    );
  }

  Widget _buildLineEditor(
    String label,
    Map<String, dynamic> line,
    int qty,
    ValueChanged<int> onQtyChanged,
  ) {
    return Card(
      child: ListTile(
        title: Text('$label: ${line['name']}'),
        subtitle: Text('Jednostka: ${line['unit']}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: qty > 1 ? () => onQtyChanged(qty - 1) : null,
            ),
            Text('$qty'),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => onQtyChanged(qty + 1),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSwap() async {
    if (_oldItemId == null || _newItemId == null) return;

    if (_oldItemId == _newItemId) {
      final diff = _newQty - _oldQty;
      if (diff == 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Brak zmian do wymiany')));
        return;
      }
      if (diff > 0) {
        await StockService.applySwap(
          customerId: widget.customerId,
          projectId: widget.projectId,
          oldItemId: _oldItemId!,
          oldQty: 0,
          newItemId: _newItemId!,
          newQty: diff,
        );
      } else {
        await StockService.applySwap(
          customerId: widget.customerId,
          projectId: widget.projectId,
          oldItemId: _oldItemId!,
          oldQty: -diff,
          newItemId: _newItemId!,
          newQty: 0,
        );
      }
    } else {
      await StockService.applySwap(
        customerId: widget.customerId,
        projectId: widget.projectId,
        oldItemId: _oldItemId!,
        oldQty: _oldQty,
        newItemId: _newItemId!,
        newQty: _newQty,
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Swap wykonany')));
  }
}
