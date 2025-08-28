// lib/widgets/project_line_dialog.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:strefa_ciszy/models/project_line.dart';
import 'package:strefa_ciszy/models/stock_item.dart';
import 'package:strefa_ciszy/screens/scan_screen.dart';
import 'package:strefa_ciszy/screens/swap_workflow_screen.dart';
import 'package:strefa_ciszy/services/api_service.dart';
import 'package:strefa_ciszy/utils/search_utils.dart';

Future<ProjectLine?> showProjectLineDialog(
  BuildContext context,
  List<StockItem> stockItems, {
  required String customerId,
  required String projectId,
  required bool isAdmin,
  ProjectLine? existing,
  Map<String, int> existingLines = const {},
}) {
  bool isStock = existing?.isStock ?? true;
  String itemRef = existing?.itemRef ?? '';

  String initialProductLabel = '';
  if (existing?.isStock == true) {
    final s = stockItems.firstWhere((s) => s.id == existing!.itemRef);
    initialProductLabel = '${s.name}, ${s.producent}';
  }
  final productController = TextEditingController(text: initialProductLabel);

  final customController = TextEditingController(
    text: existing?.customName ?? '',
  );

  int prevQty = existing?.previousQty ?? existingLines[itemRef] ?? 0;
  final qtyController = TextEditingController(text: '0');

  String unit = existing?.unit ?? 'szt';
  final formKey = GlobalKey<FormState>();

  String initialLabel = '';
  if (existing?.isStock == true) {
    final s = stockItems.firstWhere((s) => s.id == existing!.itemRef);
    initialLabel = '${s.name}, ${s.producent}';
  }
  bool didInitAuto = false;

  final dssController = DraggableScrollableController();

  return showModalBottomSheet<ProjectLine>(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),

    builder: (ctx) {
      bool hasItemInAnyRW = false;

      TextEditingController? _autoCtrl;
      FocusNode? _autoFocus;

      /// api
      List<StockItem> _autoOpts = [];
      Timer? _debounce;
      StockItem? _selectedItem;

      final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
      return AnimatedPadding(
        padding: EdgeInsets.only(bottom: bottomInset),
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: DraggableScrollableSheet(
          controller: dssController,
          initialChildSize: 0.95,
          minChildSize: 0.5,
          maxChildSize: 1.0,
          expand: true,
          builder: (ctx, scrollController) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16,
              ),

              child: StatefulBuilder(
                builder: (ctx, setState) {
                  // TextEditingController? _autoCtrl;
                  // FocusNode? _autoFocus;

                  Future<void> _refetchOptions(String q) async {
                    final query = q.trim();
                    if (query.isEmpty) {
                      if (!ctx.mounted) return;
                      setState(() {
                        _autoOpts = [];
                      });
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_autoFocus?.hasFocus ?? false)
                          _autoCtrl?.notifyListeners();
                      });
                      return;
                    }

                    final isBarcode = RegExp(r'^\d{6,}$').hasMatch(query);
                    final tokens = normalize(
                      query,
                    ).split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

                    final isMulti = tokens.length > 1;
                    final seedToken = isBarcode
                        ? query
                        : (tokens..sort((a, b) => b.length.compareTo(a.length)))
                              .first;

                    final fetchLimit = isBarcode ? 50 : (isMulti ? 1000 : 200);

                    final results = await ApiService.fetchProducts(
                      search: seedToken,
                      limit: fetchLimit,
                      offset: 0,
                    );

                    final List<StockItem> filtered = isBarcode
                        ? (() {
                            final exact = results.where(
                              (it) => it.barcode.trim() == query,
                            );
                            return exact.isNotEmpty ? exact.toList() : results;
                          })()
                        : results.where((it) {
                            return matchesAllTokens(query, [
                              it.name,
                              it.producent,
                              it.category.isNotEmpty
                                  ? it.category
                                  : it.description,
                              it.sku,
                              it.barcode,
                            ]);
                          }).toList();

                    if (!ctx.mounted) return;
                    setState(() => _autoOpts = filtered.take(50).toList());

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_autoFocus?.hasFocus ?? false)
                        _autoCtrl?.notifyListeners();
                    });
                  }

                  Future<void> _showListFromQuery(
                    String q, {
                    bool maybePickBarcode = false,
                    Future<void> Function(StockItem)? select,
                  }) async {
                    if (!ctx.mounted) return;

                    // put text + focus (this usually opens overlay if options already exist)
                    _autoCtrl?.value = TextEditingValue(
                      text: q,
                      selection: TextSelection.collapsed(offset: q.length),
                    );
                    if (!(_autoFocus?.hasFocus ?? true))
                      _autoFocus?.requestFocus();

                    // 🔔 immediate nudge (helps when options are already there)
                    _autoCtrl?.notifyListeners();

                    await _refetchOptions(
                      q,
                    ); // will also ping after options arrive

                    if (maybePickBarcode && RegExp(r'^\d{6,}$').hasMatch(q)) {
                      final exact = _autoOpts.where(
                        (it) => it.barcode.trim() == q,
                      );
                      if (exact.isNotEmpty && select != null)
                        await select(exact.first);
                    }
                  }

                  Future<void> checkIfItemInRW(String ref) async {
                    if (ref.isEmpty) {
                      setState(() => hasItemInAnyRW = false);
                      return;
                    }

                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);

                    final snap = await FirebaseFirestore.instance
                        .collection('customers')
                        .doc(customerId)
                        .collection('projects')
                        .doc(projectId)
                        .collection('rw_documents')
                        .get();

                    bool found = false;
                    for (final doc in snap.docs) {
                      final data = doc.data();
                      final createdAt = (data['createdAt'] as Timestamp?)
                          ?.toDate();

                      if (createdAt != null &&
                          createdAt.isBefore(today.add(Duration(days: 1)))) {
                        final items = (data['items'] as List<dynamic>? ?? []);
                        if (items.any((it) => it['itemId'] == ref)) {
                          found = true;
                          break;
                        }
                      }
                    }

                    if (ctx.mounted) setState(() => hasItemInAnyRW = found);
                  }

                  if (itemRef.isNotEmpty) {
                    checkIfItemInRW(itemRef);
                  }

                  return SingleChildScrollView(
                    controller: scrollController,
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            existing == null ? 'Dodaj' : 'Edytuj',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          SizedBox(height: 16),

                          DropdownButtonFormField<bool>(
                            value: isStock,
                            decoration: const InputDecoration(
                              labelText: 'Produkt',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: true,
                                child: Text('W Magazynie'),
                              ),
                              DropdownMenuItem(
                                value: false,
                                child: Text('Custom'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                isStock = v;
                                itemRef = '';
                                _selectedItem = null;
                                customController.clear();
                                productController.clear();
                                _autoOpts = [];
                              });
                            },
                          ),

                          SizedBox(height: 12),

                          if (isStock)
                            Autocomplete<StockItem>(
                              optionsBuilder: (TextEditingValue te) {
                                final q = te.text.trim();
                                if (q.isEmpty) return const <StockItem>[];
                                return _autoOpts;
                              },

                              displayStringForOption: (s) =>
                                  '${s.name}, ${s.producent}, ${s.description}',
                              fieldViewBuilder: (ctx, textCtrl, focusNode, onSubmit) {
                                // cache the real controller/focus used by RawAutocomplete
                                _autoCtrl ??= textCtrl;
                                _autoFocus ??= focusNode;

                                if (!didInitAuto && initialLabel.isNotEmpty) {
                                  textCtrl.text = initialLabel;
                                  didInitAuto = true;
                                }

                                return TextFormField(
                                  controller: textCtrl,
                                  focusNode: focusNode,
                                  decoration: InputDecoration(
                                    labelText: 'Szukaj produkt',
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.qr_code_scanner),
                                      onPressed: () async {
                                        final code = await Navigator.of(context)
                                            .push<String>(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const ScanScreen(
                                                      returnCode: true,
                                                    ),
                                              ),
                                            );
                                        if (code == null || code.trim().isEmpty)
                                          return;
                                        final q = code.trim();

                                        // Fill field, open list; if barcode -> auto-pick exact match
                                        await _showListFromQuery(
                                          q,
                                          maybePickBarcode: true,
                                          select: (s) async {
                                            setState(() {
                                              _selectedItem = s;
                                              itemRef = s.id;
                                              unit = s.unit.isNotEmpty
                                                  ? s.unit
                                                  : 'szt';
                                              productController.text =
                                                  '${s.name}, ${s.producent}';
                                              prevQty =
                                                  existing?.previousQty ??
                                                  (existingLines[s.id] ?? 0);
                                            });
                                            await checkIfItemInRW(s.id);
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                  onChanged: (v) {
                                    setState(() {}); // keep UI responsive
                                    _debounce?.cancel();
                                    _debounce = Timer(
                                      const Duration(milliseconds: 250),
                                      () {
                                        _refetchOptions(v);
                                      },
                                    );
                                  },
                                  onFieldSubmitted: (v) {
                                    // If user presses Enter, also open list right away
                                    _showListFromQuery(v);
                                  },
                                  validator: (v) => isStock && itemRef.isEmpty
                                      ? 'Wybierz produkt.'
                                      : null,
                                );
                              },

                              //// ean: 5902983719250
                              optionsViewBuilder:
                                  (
                                    BuildContext ctx,
                                    AutocompleteOnSelected<StockItem>
                                    onSelected,
                                    Iterable<StockItem> options,
                                  ) {
                                    final mq = MediaQuery.of(ctx);
                                    final maxHeight = mq.size.height * 0.7;

                                    return Align(
                                      alignment: Alignment.topLeft,
                                      child: GestureDetector(
                                        onTapDown: (_) =>
                                            FocusScope.of(ctx).unfocus(),
                                        onVerticalDragStart: (_) =>
                                            FocusScope.of(ctx).unfocus(),
                                        behavior: HitTestBehavior.translucent,
                                        child: Material(
                                          elevation: 4,
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(
                                              maxHeight: maxHeight,
                                            ),
                                            child: NotificationListener<ScrollNotification>(
                                              onNotification: (notification) {
                                                if (notification
                                                    is ScrollStartNotification) {
                                                  SystemChannels.textInput
                                                      .invokeMethod(
                                                        'TextInput.hide',
                                                      );
                                                }
                                                return false;
                                              },
                                              child: ListView.builder(
                                                padding: EdgeInsets.zero,
                                                itemCount: options.length,
                                                itemBuilder: (BuildContext ctx2, int index) {
                                                  final StockItem s = options
                                                      .elementAt(index);

                                                  final tile = ListTile(
                                                    dense: true,
                                                    minVerticalPadding: 0,
                                                    visualDensity:
                                                        VisualDensity(
                                                          vertical: -2,
                                                        ),
                                                    contentPadding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    tileColor:
                                                        Colors.transparent,
                                                    selectedTileColor:
                                                        Colors.transparent,
                                                    title: Text(
                                                      '${s.name}, ${s.producent}',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    trailing: Text(
                                                      'Stan: ${s.quantity}',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: s.quantity <= 0
                                                            ? Colors.red
                                                            : Colors.blueGrey,
                                                      ),
                                                    ),
                                                    onTap: () {
                                                      FocusScope.of(
                                                        ctx,
                                                      ).unfocus();
                                                      onSelected(s);
                                                    },
                                                  );

                                                  if (index.isEven) {
                                                    return Container(
                                                      margin:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 2,
                                                            horizontal: 4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black
                                                                .withValues(
                                                                  alpha: 0.05,
                                                                ),
                                                            blurRadius: 2,
                                                            offset: Offset(
                                                              0,
                                                              1,
                                                            ),
                                                          ),
                                                        ],
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                      ),
                                                      child: ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                        child: tile,
                                                      ),
                                                    );
                                                  }
                                                  return tile;
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },

                              onSelected: (s) async {
                                setState(() {
                                  _selectedItem = s;
                                  itemRef = s.id;
                                  unit = s.unit.isNotEmpty ? s.unit : 'szt';
                                  productController.text =
                                      '${s.name}, ${s.producent}';
                                  prevQty =
                                      existing?.previousQty ??
                                      existingLines[s.id] ??
                                      0;
                                });
                                await checkIfItemInRW(s.id);
                              },
                              //////
                            ),

                          if (!isStock)
                            TextFormField(
                              controller: customController,
                              decoration: InputDecoration(
                                labelText: 'Nazwa custom',
                              ),
                              validator: (v) =>
                                  (!isStock && (v?.trim().isEmpty ?? true))
                                  ? 'Wprowadź nazwę.'
                                  : null,
                              onChanged: (v) => setState(() {}),
                            ),

                          SizedBox(height: 12),

                          TextFormField(
                            controller: qtyController,
                            decoration: InputDecoration(
                              labelText: 'Ilość',
                              suffixText: prevQty > 0
                                  ? '(wcześniej dodano: $prevQty)'
                                  : null,
                            ),
                            keyboardType: TextInputType.number,

                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              if (n == null || n < 0) {
                                return 'Nieprawidłowa ilość';
                              }

                              if (isStock) {
                                // live quantity
                                final idx = stockItems.indexWhere(
                                  (s) => s.id == itemRef,
                                );
                                final available =
                                    _selectedItem?.quantity ??
                                    (idx == -1 ? 0 : stockItems[idx].quantity);

                                final takenBefore = existing?.previousQty ?? 0;
                                final delta = n - takenBefore;
                                if (delta > available) {
                                  final maxTotal = available + takenBefore;
                                  return 'Za mało w magazynie (max: $maxTotal)';
                                }
                              }
                              return null;
                            },
                          ),

                          SizedBox(height: 24),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('Anuluj'),
                              ),

                              if (isStock &&
                                  itemRef.isNotEmpty &&
                                  hasItemInAnyRW)
                                ElevatedButton(
                                  onPressed: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => SwapWorkflowScreen(
                                          customerId: customerId,
                                          projectId: projectId,
                                          preselectedItemId: itemRef,
                                          isAdmin: isAdmin,
                                        ),
                                      ),
                                    );
                                    if (ctx.mounted) {
                                      Navigator.of(ctx).pop();
                                    }
                                  },
                                  child: const Icon(
                                    Icons.swap_horizontal_circle,
                                    color: Color.fromARGB(255, 148, 115, 13),
                                  ),
                                ),

                              ElevatedButton(
                                onPressed: () {
                                  if (!formKey.currentState!.validate()) return;
                                  if (isStock && itemRef.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Wybierz produkt.'),
                                      ),
                                    );
                                    return;
                                  }

                                  final added =
                                      int.tryParse(qtyController.text.trim()) ??
                                      0;
                                  final newQty = prevQty + added;

                                  int originalStock;
                                  if (isStock) {
                                    final idx = stockItems.indexWhere(
                                      (s) => s.id == itemRef,
                                    );
                                    originalStock =
                                        _selectedItem?.quantity ??
                                        (idx == -1
                                            ? 0
                                            : stockItems[idx].quantity);
                                  } else {
                                    originalStock = 0;
                                  }

                                  final line = ProjectLine(
                                    isStock: isStock,
                                    itemRef: itemRef,
                                    customName: isStock
                                        ? ''
                                        : customController.text.trim(),
                                    requestedQty: newQty,
                                    unit: unit,
                                    originalStock: originalStock,
                                    previousQty: prevQty,
                                    updatedAt: DateTime.now(),
                                  );

                                  Navigator.of(ctx).pop(line);
                                },
                                child: Text(
                                  existing == null ? 'Dodaj' : 'Zapisz',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      );
    },
  );
}
