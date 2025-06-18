// lib/widgets/project_line_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final customController = TextEditingController(
    text: existing?.customName ?? '',
  );
  int qty = existing?.requestedQty ?? 0;
  String unit = existing?.unit ?? 'szt';
  final formKey = GlobalKey<FormState>();

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

                    // Product type selector
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
                            (s) => s.name.toLowerCase().contains(q),
                          );
                        },
                        displayStringForOption: (s) => s.name,
                        fieldViewBuilder:
                            (context, textCtrl, focusNode, onSubmit) {
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
                                            textCtrl.text =
                                                data['name'] as String;
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
                        onSelected: (s) => setState(() => itemRef = s.id),
                      ),

                    // Custom name field
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
                    // Quantity
                    TextFormField(
                      initialValue: qty.toString(),
                      decoration: InputDecoration(labelText: 'Ilość'),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n < 0) return 'Nieprawidłowa ilość';
                        if (isStock) {
                          final available = stockItems
                              .firstWhere(
                                (s) => s.id == itemRef,
                                orElse: () =>
                                    StockItem(id: '', name: '', quantity: 0),
                              )
                              .quantity;
                          if (n > available) {
                            return 'Za mało w magazynie (max: $available)';
                          }
                        }
                        return null;
                      },
                      onChanged: (v) => qty = int.tryParse(v) ?? qty,
                    ),

                    SizedBox(height: 12),
                    // Unit
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
                    // Actions
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
                            final line = ProjectLine(
                              isStock: isStock,
                              itemRef: itemRef,
                              customName: isStock
                                  ? ''
                                  : customController.text.trim(),
                              requestedQty: qty,
                              unit: unit,
                              originalStock: chosen.quantity,
                              previousQty: existing?.previousQty ?? 0,
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
