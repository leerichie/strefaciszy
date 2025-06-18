Future<ProjectLine?> showProjectLineDialog(
  BuildContext context,
  List<StockItem> stockItems, {
  ProjectLine? existing,
}) {
  Future<ProjectLine?> _openLineDialog({ProjectLine? existing}) async {
    // 1) Local editable state
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
                      // ▲ Title
                      Text(
                        existing == null ? 'Dodaj' : 'Edytuj',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SizedBox(height: 16),

                      // 1) Stock vs. Custom selector
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

                      // 2a) Autocomplete for stock items
                      if (isStock)
                        Autocomplete<StockItem>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            final query = textEditingValue.text.toLowerCase();
                            if (query.isEmpty) return const <StockItem>[];
                            return _stockItems.where(
                              (s) => s.name.toLowerCase().contains(query),
                            );
                          },
                          displayStringForOption: (s) => s.name,
                          onSelected: (selection) {
                            setState(() {
                              itemRef = selection.id;
                            });
                          },
                          fieldViewBuilder:
                              (
                                context,
                                textController,
                                focusNode,
                                onSubmitted,
                              ) {
                                // initialize from existing
                                if (existing != null &&
                                    existing.isStock &&
                                    textController.text.isEmpty) {
                                  final name = _stockItems
                                      .firstWhere((s) => s.id == itemRef)
                                      .name;
                                  textController.text = name;
                                  textController.selection =
                                      TextSelection.collapsed(
                                        offset: name.length,
                                      );
                                }
                                return TextFormField(
                                  controller: textController,
                                  focusNode: focusNode,
                                  decoration: InputDecoration(
                                    labelText: 'Szukaj produkt',
                                    suffixIcon: IconButton(
                                      icon: Icon(Icons.qr_code_scanner),
                                      onPressed: () async {
                                        final code = await Navigator.of(context)
                                            .push<String>(
                                              MaterialPageRoute(
                                                builder: (_) => ScanScreen(
                                                  returnCode: true,
                                                ),
                                                fullscreenDialog: true,
                                              ),
                                            );
                                        if (code?.isNotEmpty ?? false) {
                                          final querySnap =
                                              await FirebaseFirestore.instance
                                                  .collection('stock_items')
                                                  .where(
                                                    'barcode',
                                                    isEqualTo: code,
                                                  )
                                                  .limit(1)
                                                  .get();
                                          if (querySnap.docs.isNotEmpty) {
                                            final doc = querySnap.docs.first;
                                            final data = doc.data();
                                            setState(() {
                                              itemRef = doc.id;
                                              textController.text =
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
                        ),

                      // 2b) Custom-name field
                      if (!isStock)
                        TextFormField(
                          controller: customController,
                          decoration: InputDecoration(
                            labelText: 'Nazwa custom',
                          ),
                          validator: (v) {
                            if (!isStock && (v == null || v.trim().isEmpty)) {
                              return 'Wprowadź nazwę.';
                            }
                            return null;
                          },
                          onChanged: (v) => setState(() {}),
                        ),

                      SizedBox(height: 12),

                      // 3) Quantity
                      TextFormField(
                        initialValue: qty.toString(),
                        decoration: InputDecoration(labelText: 'Ilość'),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n < 0) return 'Invalid';
                          return null;
                        },
                        onChanged: (v) => qty = int.tryParse(v) ?? qty,
                      ),

                      SizedBox(height: 12),

                      // 4) Unit
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

                      // 5) Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(null),
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

                              // determine originalStock & previousQty
                              final chosenStock = isStock
                                  ? _stockItems.firstWhere(
                                      (s) => s.id == itemRef,
                                    )
                                  : StockItem(
                                      id: '',
                                      name: customController.text.trim(),
                                      unit: unit,
                                      quantity: 0,
                                    );

                              final newLine = ProjectLine(
                                isStock: isStock,
                                itemRef: itemRef,
                                customName: isStock
                                    ? ''
                                    : customController.text.trim(),
                                requestedQty: qty,
                                unit: unit,
                                originalStock: chosenStock.quantity,
                                previousQty:
                                    existing?.previousQty ??
                                    chosenStock.quantity,
                              );

                              Navigator.of(ctx).pop(newLine);
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
}
