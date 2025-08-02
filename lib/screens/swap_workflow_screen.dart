// lib/screens/swap_workflow_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:strefa_ciszy/screens/scan_screen.dart';
import 'package:strefa_ciszy/services/audit_service.dart';
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

enum _Mode { swap, returnOnly }

class _SwapWorkflowScreenState extends State<SwapWorkflowScreen>
    with TickerProviderStateMixin {
  String? _oldItemId;
  int _oldQty = 1;
  Map<String, dynamic>? _oldLine;
  int _oldInstalledQty = 1;

  String? _newItemId;
  int _newQty = 1;
  Map<String, dynamic>? _newLine;
  int _newAvailableStock = 0;

  late final TabController _tabController;
  DocumentReference<Map<String, dynamic>>? _sourceRwRef;

  _Mode get _mode => _tabController.index == 0 ? _Mode.swap : _Mode.returnOnly;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 1);
    _tabController.addListener(() {
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startOldScan();
    });
  }

  void _startOldScan() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ScanScreen(
              returnCode: true,
              titleText: 'Produkt do zwrotu',
              onScanned: _onOldScanned,
            ),
          ),
        )
        .then((_) {
          if (mounted) setState(() {});
        });
  }

  Future<void> _onOldScanned(String code) async {
    final entry = await StockService.findLatestRwEntryForInput(
      widget.customerId,
      widget.projectId,
      code,
    );

    if (entry == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie znaleziono "$code" w projekcie!')),
      );
      _startOldScan();
      return;
    }

    final line = Map<String, dynamic>.from(entry['matchedLine'] as Map);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Produkt znaleziono:'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${line['producent'] ?? '–'}'),
            Text('${line['name'] ?? '–'}'),
            const Divider(),
            Text(
              'Zainstalowano: ${line['quantity'] ?? '–'} ${line['unit'] ?? ''}',
            ),
            const SizedBox(height: 8),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Szukaj ponownie'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Użyj'),
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
      _oldInstalledQty = (line['quantity'] as num?)?.toInt() ?? 1;
      _oldQty = _oldInstalledQty;
      _tabController.index = 1;

      _sourceRwRef =
          (entry['rwDoc'] as DocumentSnapshot<Map<String, dynamic>>).reference;
    });
  }

  void _startNewScan() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ScanScreen(
              returnCode: true,
              purpose: ScanPurpose.search,
              titleText: 'Szukaj nowy produkt',
              onScanned: _onNewScanned,
            ),
          ),
        )
        .then((_) {
          if (mounted) setState(() {});
        });
  }

  Future<void> _onNewScanned(String code) async {
    final candidates = await StockService.searchStockItems(code);
    if (candidates.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie znaleziono produktu: "$code"')),
      );
      return;
    }

    String chosenId;
    Map<String, dynamic> chosenData;

    if (candidates.length == 1) {
      chosenId = candidates.first.id;
      chosenData = Map<String, dynamic>.from(candidates.first.data());
    } else {
      final pick = await _pickProductFullScreen(candidates);
      if (pick == null) return;
      chosenId = pick;
      final pickedDoc = candidates.firstWhere((d) => d.id == pick);
      chosenData = Map<String, dynamic>.from(pickedDoc.data());
    }

    try {
      final stock = await StockService.lookupItemDetails(chosenId);
      final stockDoc = await FirebaseFirestore.instance
          .collection('stock_items')
          .doc(chosenId)
          .get();
      final stockQty = (stockDoc.data()?['quantity'] as num?)?.toInt() ?? 0;

      if (stockQty <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Produkt "${stock['name']}" jest niedostępny (stan 0). Skanuj ponownie.',
            ),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 500));
        _startNewScan();
        return;
      }

      setState(() {
        _newItemId = chosenId;
        _newLine = stock;
        _newQty = 1;
        _newAvailableStock = stockQty;
        _tabController.index = 0;
      });
    } catch (e) {
      final stockDoc = await FirebaseFirestore.instance
          .collection('stock_items')
          .doc(chosenId)
          .get();
      final stockQty = (stockDoc.data()?['quantity'] as num?)?.toInt() ?? 0;

      if (stockQty <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Produkt "${chosenData['name']}" jest niedostępny (stan 0). Skanuj ponownie.',
            ),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 500));
        _startNewScan();
        return;
      }

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
        _newAvailableStock = stockQty;
        _tabController.index = 0;
      });
    }
  }

  Future<void> _refreshOldLine() async {
    if (_oldItemId == null) return;
    final entry = await StockService.findLatestRwEntryForInput(
      widget.customerId,
      widget.projectId,
      _oldItemId!,
    );
    if (entry == null) return;
    final line = Map<String, dynamic>.from(entry['matchedLine'] as Map);
    setState(() {
      _oldLine = line;
      _oldInstalledQty = (line['quantity'] as num?)?.toInt() ?? 1;
      _oldQty = _oldQty.clamp(1, _oldInstalledQty);
    });
  }

  Color _stockColor(int stock) {
    if (stock <= 0) return Colors.red;
    if (stock <= 2) return Colors.orange;
    return Colors.green;
  }

  Future<String?> _pickProductFullScreen(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> candidates,
  ) {
    return Navigator.of(context).push<String?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            title: const Text('Wybierz produkt'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(ctx, null),
            ),
          ),
          body: SafeArea(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: candidates.length + 1,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, index) {
                if (index == 0) {
                  return const SizedBox.shrink();
                }
                final doc = candidates[index - 1];
                final d = doc.data();
                final name = d['name'] ?? '';
                final producent = d['producent'] ?? '';
                final qty = (d['quantity'] ?? 0) as num;
                return ListTile(
                  title: Text('$producent'),
                  subtitle: Text('$name'),
                  trailing: Text(
                    'Stan: ${qty.toInt()}',
                    style: TextStyle(
                      color: _stockColor((qty).toInt()),
                      fontSize: 12,
                    ),
                  ),
                  onTap: () => Navigator.pop(ctx, doc.id),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onConfirmPressed() async {
    await _refreshOldLine();

    if (_sourceRwRef == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Brak źródłowego dokumentu RW')),
      );
      return;
    }

    if (_mode == _Mode.swap) {
      if (_newAvailableStock <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Niemozliwe! Szukaj produkt o stan dodatni.'),
          ),
        );
        return;
      }
      if (_oldItemId == null || _newItemId == null) return;

      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Na pewno zamienić?'),
          content: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              children: [
                TextSpan(
                  text: 'Zwracasz:\n',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text:
                      '${_oldLine?['producent'] ?? ''} ${_oldLine?['name'] ?? _oldItemId}\n',
                ),
                TextSpan(text: '$_oldQty ${_oldLine?['unit'] ?? ''}\n\n'),
                TextSpan(
                  text: 'Instalujesz:\n',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text:
                      '${_newLine?['producent'] ?? ''} ${_newLine?['name'] ?? _newItemId}\n',
                ),
                TextSpan(text: '$_newQty ${_newLine?['unit'] ?? ''}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Anuluj', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Tak'),
            ),
          ],
        ),
      );

      if (proceed != true) return;

      // perform swap with error handling
      try {
        if (_oldItemId == _newItemId) {
          final diff = _newQty - _oldQty;
          if (diff == 0) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Brak zmian do wymiany')),
            );
            return;
          }
          if (diff > 0) {
            await StockService.applySwapOnExistingRw(
              sourceRwRef: _sourceRwRef!,
              customerId: widget.customerId,
              projectId: widget.projectId,
              oldItemId: _oldItemId!,
              oldQty: 0,
              newItemId: _newItemId!,
              newQty: diff,
            );
          } else {
            await StockService.applySwapOnExistingRw(
              sourceRwRef: _sourceRwRef!,
              customerId: widget.customerId,
              projectId: widget.projectId,
              oldItemId: _oldItemId!,
              oldQty: -diff,
              newItemId: _newItemId!,
              newQty: 0,
            );
          }
        } else {
          await StockService.applySwapOnExistingRw(
            sourceRwRef: _sourceRwRef!,
            customerId: widget.customerId,
            projectId: widget.projectId,
            oldItemId: _oldItemId!,
            oldQty: _oldQty,
            newItemId: _newItemId!,
            newQty: _newQty,
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Błąd wykonania zamiany: $e')));
        return;
      }
    } else {
      // return only
      if (_oldItemId == null) return;

      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Na pewno zwrócić?'),
          content: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              children: [
                TextSpan(
                  text:
                      '${_oldLine?['producent'] ?? ''} ${_oldLine?['name'] ?? _oldItemId}\n',
                ),
                TextSpan(text: '$_oldQty ${_oldLine?['unit'] ?? ''}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Anuluj', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Tak'),
            ),
          ],
        ),
      );
      if (proceed != true) return;

      try {
        await StockService.applySwapOnExistingRw(
          sourceRwRef: _sourceRwRef!,
          customerId: widget.customerId,
          projectId: widget.projectId,
          oldItemId: _oldItemId!,
          oldQty: _oldQty,
          newItemId: _oldItemId!,
          newQty: 0,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Błąd wykonania zwrotu: $e')));
        return;
      }
    }

    if (!mounted) return;

    // Audit logging (mode-aware, avoids null newLine on return)
    final oldName =
        '${_oldLine?['producent'] ?? ''} ${_oldLine?['name'] ?? _oldItemId}';
    final oldSummary = '$_oldQty x $oldName';

    if (_mode == _Mode.swap) {
      final newName =
          '${_newLine?['producent'] ?? ''} ${_newLine?['name'] ?? _newItemId}';
      final newSummary = '$_newQty x $newName';
      await AuditService.logAction(
        action: 'Zamiana',
        customerId: widget.customerId,
        projectId: widget.projectId,
        details: {'Produkt': oldSummary, 'Zmiana': newSummary},
      );
    } else {
      await AuditService.logAction(
        action: 'Zwrot',
        customerId: widget.customerId,
        projectId: widget.projectId,
        details: {
          'Klient': '',
          'Projekt': '',
          'Produkt': oldSummary,
          'Zmiana': 'Zwrot',
        },
      );
    }

    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Akcja wykonana')));
  }

  Widget _buildLineEditor(
    String label,
    Map<String, dynamic> line,
    int qty,
    ValueChanged<int> onQtyChanged, {
    Widget? extraInfoWidget,
  }) {
    return Card(
      child: ListTile(
        title: Text(
          '$label:',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (line['producent'] != null) Text('${line['producent']}'),
            if (line['name'] != null) Text('${line['name']}'),
            const Divider(),
            if (extraInfoWidget != null) extraInfoWidget,
          ],
        ),
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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bothReady = _oldLine != null && _newLine != null;
    final readyReturn = _oldLine != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zamiana / Zwrot'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Zamiana'),
            Tab(text: 'Zwrot'),
          ],
        ),
      ),
      floatingActionButton: Builder(
        builder: (context) {
          if (_mode == _Mode.swap && _oldLine != null) {
            return FloatingActionButton(
              tooltip: 'Szukaj nowy produkt',
              onPressed: _startNewScan,
              child: const Icon(Icons.search_sharp),
            );
          } else if (_mode == _Mode.returnOnly) {
            return FloatingActionButton(
              tooltip: 'Szukaj produkt do zwrotu',
              onPressed: _startOldScan,
              child: const Icon(Icons.search_sharp),
            );
          }
          return SizedBox.shrink();
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      body: TabBarView(
        controller: _tabController,
        children: [
          // Zamiana
          bothReady
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildLineEditor(
                        'Zwracasz',
                        _oldLine!,
                        _oldQty,
                        (q) {
                          final bounded = q.clamp(1, _oldInstalledQty);
                          setState(() => _oldQty = bounded);
                        },
                        extraInfoWidget: Text(
                          'Zainstalowano: $_oldInstalledQty ${_oldLine?['unit'] ?? ''}',
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildLineEditor(
                        'Instalujesz',
                        _newLine!,
                        _newQty,
                        (q) {
                          final bounded = q.clamp(1, _newAvailableStock);
                          setState(() => _newQty = bounded);
                        },
                        extraInfoWidget: Text(
                          'Stan: $_newAvailableStock',
                          style: TextStyle(
                            color: _stockColor(_newAvailableStock),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _onConfirmPressed,
                        child: const Text(
                          'Potwierdz zamiana',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _oldLine == null
                          ? 'Szukaj produkt do zwrotu'
                          : 'Szukaj nowy produkt',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),

          // Zwrot
          readyReturn
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildLineEditor(
                        'Zwracasz',
                        _oldLine!,
                        _oldQty,
                        (q) {
                          final bounded = q.clamp(1, _oldInstalledQty);
                          setState(() => _oldQty = bounded);
                        },
                        extraInfoWidget: Text(
                          'Zainstalowano: $_oldInstalledQty ${_oldLine?['unit'] ?? ''}',
                        ),
                      ),
                      const Divider(),
                      ElevatedButton(
                        onPressed: _onConfirmPressed,
                        child: const Text(
                          'Potwierdz zwrot',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Szukaj produkt do zwrotu',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
