// lib/widgets/project_line_dialog.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:strefa_ciszy/models/project_line.dart';
import 'package:strefa_ciszy/models/stock_item.dart';
import 'package:strefa_ciszy/screens/scan_screen.dart';

Future<ProjectLine?> showProjectLineDialog(
  BuildContext context,
  List<StockItem> stockItems, {
  ProjectLine? existing,
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
  // int qty = existing?.requestedQty ?? 0;
  final qtyController = TextEditingController(
    text: existing?.requestedQty.toString() ?? '0',
  );
  String unit = existing?.unit ?? 'szt';
  final formKey = GlobalKey<FormState>();

  String initialLabel = '';
  if (existing?.isStock == true) {
    final s = stockItems.firstWhere((s) => s.id == existing!.itemRef);
    initialLabel = '${s.name}, ${s.producent}';
  }
  bool didInitAuto = false;

  return showModalBottomSheet<ProjectLine>(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: bottomInset + 16,
        ),
        child: StatefulBuilder(
          builder: (ctx, setState) {
            return SingleChildScrollView(
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
                      decoration: InputDecoration(labelText: 'Produkt'),
                      items: [
                        DropdownMenuItem(
                          value: true,
                          child: Text('W Magazynie'),
                        ),
                        DropdownMenuItem(value: false, child: Text('Custom')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          isStock = v;
                          itemRef = '';
                          customController.clear();
                          productController.clear();
                        });
                      },
                    ),
                    SizedBox(height: 12),

                    // Autocomplete for stock items
                    if (isStock)
                      Autocomplete<StockItem>(
                        optionsBuilder: (TextEditingValue te) {
                          final q = te.text.toLowerCase();
                          if (q.isEmpty) return const <StockItem>[];
                          return stockItems.where(
                            (s) =>
                                s.name.toLowerCase().contains(q) ||
                                s.producent!.toLowerCase().contains(q),
                          );
                        },
                        displayStringForOption: (s) =>
                            '${s.name}, ${s.producent}',
                        fieldViewBuilder: (ctx, textCtrl, focusNode, onSubmit) {
                          // seed in the existing name once
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
                                icon: Icon(Icons.qr_code_scanner),
                                onPressed: () async {
                                  final code = await Navigator.of(context)
                                      .push<String>(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              ScanScreen(returnCode: true),
                                          fullscreenDialog: true,
                                        ),
                                      );
                                  if (code != null && code.isNotEmpty) {
                                    final snap = await FirebaseFirestore
                                        .instance
                                        .collection('stock_items')
                                        .where('barcode', isEqualTo: code)
                                        .limit(1)
                                        .get();
                                    if (snap.docs.isNotEmpty) {
                                      final doc = snap.docs.first;
                                      final data = doc.data();
                                      setState(() {
                                        itemRef = doc.id;
                                        productController.text =
                                            data['name'] as String;
                                        unit = data['unit'] as String;
                                      });
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Nie znaleziono produktu: $code',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                            validator: (v) => isStock && itemRef.isEmpty
                                ? 'Wybierz produkt.'
                                : null,
                          );
                        },
                        onSelected: (s) => setState(() {
                          itemRef = s.id;
                          unit = s.unit!;
                          productController.text = '${s.name}, ${s.producent}';
                        }),
                      ),

                    if (!isStock)
                      TextFormField(
                        controller: customController,
                        decoration: InputDecoration(labelText: 'Nazwa custom'),
                        validator: (v) =>
                            (!isStock && (v?.trim().isEmpty ?? true))
                            ? 'Wprowadź nazwę.'
                            : null,
                        onChanged: (v) => setState(() {}),
                      ),

                    SizedBox(height: 12),

                    // TextFormField(
                    //   initialValue: qty.toString(),
                    //   decoration: InputDecoration(labelText: 'Ilość'),
                    //   keyboardType: TextInputType.number,
                    //   validator: (v) {
                    //     final n = int.tryParse(v ?? '');
                    //     if (n == null || n < 0) return 'Nieprawidłowa ilość';

                    //     if (isStock) {
                    //       final stockItem = stockItems.firstWhere(
                    //         (s) => s.id == itemRef,
                    //         orElse: () =>
                    //             StockItem(id: '', name: '', quantity: 0),
                    //       );

                    //       final available = stockItem.quantity;
                    //       final takenBefore = existing?.previousQty ?? 0;
                    //       final delta = n - takenBefore;

                    //       if (delta > available) {
                    //         final maxTotal = available + takenBefore;
                    //         return 'Za mało w magazynie (max: $maxTotal)';
                    //       }
                    //     }

                    //     return null;
                    //   },
                    TextFormField(
                      controller: qtyController,
                      decoration: InputDecoration(
                        labelText: 'Ilość',
                        suffixText: existing != null
                            ? '(wcześniej dodano: ${existing.requestedQty})'
                            : null,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n < 0) return 'Nieprawidłowa ilość';

                        if (isStock) {
                          final stockItem = stockItems.firstWhere(
                            (s) => s.id == itemRef,
                            orElse: () =>
                                StockItem(id: '', name: '', quantity: 0),
                          );
                          final available = stockItem.quantity;
                          final takenBefore = existing?.previousQty ?? 0;
                          final delta = (n - takenBefore);
                          if (delta > available) {
                            final maxTotal = available + takenBefore;
                            return 'Za mało w magazynie (max: $maxTotal)';
                          }
                        }
                        return null;
                      },

                      // onChanged: (v) => qty = int.tryParse(v) ?? qty,
                    ),

                    SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: unit,
                      decoration: InputDecoration(labelText: 'jm.'),
                      items: ['szt', 'm', 'kg', 'kpl']
                          .map(
                            (u) => DropdownMenuItem(value: u, child: Text(u)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => unit = v ?? unit),
                    ),

                    SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text('Anuluj'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            if (!formKey.currentState!.validate()) return;
                            if (isStock && itemRef.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Wybierz produkt.')),
                              );
                              return;
                            }

                            final chosen = isStock
                                ? stockItems.firstWhere((s) => s.id == itemRef)
                                : StockItem(
                                    id: '',
                                    name: customController.text.trim(),
                                    quantity: 0,
                                  );
                            // final line = ProjectLine(
                            //   isStock: isStock,
                            //   itemRef: itemRef,
                            //   customName: isStock
                            //       ? ''
                            //       : customController.text.trim(),
                            //   requestedQty: qty,
                            //   unit: unit,
                            //   originalStock: chosen.quantity,
                            //   previousQty: existing?.previousQty ?? 0,
                            //   updatedAt: DateTime.now(),
                            // );
                            final n =
                                int.tryParse(qtyController.text.trim()) ?? 0;
                            final line = ProjectLine(
                              isStock: isStock,
                              itemRef: itemRef,
                              customName: isStock
                                  ? ''
                                  : customController.text.trim(),
                              requestedQty: n,
                              unit: unit,
                              originalStock: chosen.quantity,
                              previousQty: existing?.previousQty ?? 0,
                              updatedAt: DateTime.now(),
                            );
                            Navigator.of(ctx).pop(line);
                          },
                          child: Text(existing == null ? 'Dodaj' : 'Zapisz'),
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
  );
}
