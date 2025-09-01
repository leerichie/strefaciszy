// lib/widgets/project_line_dialog.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:strefa_ciszy/models/project_line.dart';
import 'package:strefa_ciszy/models/stock_item.dart';
import 'package:strefa_ciszy/screens/scan_screen.dart';
import 'package:strefa_ciszy/screens/swap_workflow_screen.dart';
import 'package:strefa_ciszy/services/admin_api.dart';
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

  int selectedAvailable = 0;
  if (itemRef.isNotEmpty) {
    final idx0 = stockItems.indexWhere((s) => s.id == itemRef);
    if (idx0 != -1) selectedAvailable = stockItems[idx0].quantity;
  }

  return showModalBottomSheet<ProjectLine>(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),

    builder: (ctx) {
      bool hasItemInAnyRW = false;

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
                            decoration: InputDecoration(labelText: 'Produkt'),
                            items: [
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
                                customController.clear();
                                productController.clear();
                              });
                            },
                          ),
                          SizedBox(height: 12),

                          // Autocomplete FOR stock
                          if (isStock)
                            Autocomplete<StockItem>(
                              optionsBuilder: (TextEditingValue te) {
                                final q = te.text;
                                if (q.isEmpty) return const <StockItem>[];
                                return stockItems.where(
                                  (s) => matchesSearch(q, [
                                    s.name,
                                    s.producent,
                                    s.description,
                                  ]),
                                );
                              },
                              displayStringForOption: (s) =>
                                  '${s.name}, ${s.producent}, ${s.description}',
                              fieldViewBuilder: (ctx, textCtrl, focusNode, onSubmit) {
                                if (!didInitAuto && initialLabel.isNotEmpty) {
                                  textCtrl.text = initialLabel;
                                  didInitAuto = true;
                                }
                                return TextFormField(
                                  controller:
                                      textCtrl, // This is the actual visible input
                                  focusNode: focusNode,
                                  decoration: InputDecoration(
                                    labelText: 'Szukaj produkt',

                                    // suffixIcon: IconButton(
                                    //   icon: const Icon(Icons.qr_code_scanner),
                                    //   onPressed: () async {
                                    //     final code = await Navigator.of(context)
                                    //         .push<String>(
                                    //           MaterialPageRoute(
                                    //             builder: (_) =>
                                    //                 const ScanScreen(
                                    //                   returnCode: true,
                                    //                 ),
                                    //           ),
                                    //         );
                                    //     if (code != null && code.isNotEmpty) {
                                    //       textCtrl.text = code;
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.qr_code_scanner),
                                      onPressed: () async {
                                        final code = await Navigator.of(context)
                                            .push<String>(
                                              MaterialPageRoute(
                                                builder: (_) => const ScanScreen(
                                                  returnCode: true,
                                                  purpose:
                                                      ScanPurpose.projectLine,
                                                  titleText:
                                                      'Skanuj (dodaj do projektu)',
                                                ),
                                              ),
                                            );
                                        if (code == null || code.isEmpty) {
                                          return;
                                        }

                                        // fill the text box so user sees scanned code
                                        textCtrl.text = code;

                                        try {
                                          final results =
                                              await ApiService.fetchProducts(
                                                search: code,
                                                limit: 50,
                                                offset: 0,
                                              );

                                          ////////
                                          StockItem? match;
                                          final exact = results.where(
                                            (s) =>
                                                s.barcode.trim() == code.trim(),
                                          );
                                          if (exact.isNotEmpty) {
                                            match = exact.first;
                                          } else if (results.isNotEmpty) {
                                            match = results.first;
                                          }

                                          if (match != null) {
                                            // Promote to non-nullable for use inside the closure
                                            final m = match!;

                                            setState(() {
                                              itemRef = m.id;
                                              textCtrl.text =
                                                  '${m.name}, ${m.producent}';
                                              unit = m.unit.isNotEmpty
                                                  ? m.unit
                                                  : 'szt';
                                              selectedAvailable =
                                                  m.quantity; // keep real stock
                                              prevQty =
                                                  existing?.previousQty ??
                                                  existingLines[m.id] ??
                                                  0;
                                            });

                                            await checkIfItemInRW(m.id);
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
                                        } catch (e) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Skanowanie nie powiodło się: $e',
                                              ),
                                            ),
                                          );

                                          // final snap = await FirebaseFirestore
                                          //     .instance
                                          //     .collection('stock_items')
                                          //     .where('barcode', isEqualTo: code)
                                          //     .limit(1)
                                          //     .get();

                                          // if (snap.docs.isNotEmpty) {
                                          //   final doc = snap.docs.first;
                                          //   final data = doc.data();
                                          //   setState(() {
                                          //     itemRef = doc.id;
                                          //     textCtrl.text =
                                          //         '${data['name']}, ${data['producent']}';
                                          //     unit =
                                          //         data['unit'] as String? ??
                                          //         'szt';
                                          //   });
                                          //   await checkIfItemInRW(doc.id);
                                          // } else {
                                          //   ScaffoldMessenger.of(
                                          //     context,
                                          //   ).showSnackBar(
                                          //     SnackBar(
                                          //       content: Text(
                                          //         'Nie znaleziono produktu: $code',
                                          //       ),
                                          //     ),
                                          //   );
                                          // }
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

                              // onSelected: (s) async {
                              //   setState(() {
                              //     itemRef = s.id;
                              //     unit = s.unit!;
                              //     productController.text =
                              //         '${s.name}, ${s.producent}';
                              //     prevQty =
                              //         existing?.previousQty ??
                              //         existingLines[s.id] ??
                              //         0;
                              //   });
                              //   await checkIfItemInRW(s.id);
                              // },
                              onSelected: (s) async {
                                setState(() {
                                  itemRef = s.id;
                                  unit = s.unit.isNotEmpty ? s.unit : 'szt';
                                  productController.text =
                                      '${s.name}, ${s.producent}';
                                  prevQty =
                                      existing?.previousQty ??
                                      existingLines[s.id] ??
                                      0;
                                  selectedAvailable = s.quantity; // <— NEW
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

                            // validator: (v) {
                            //   final n = int.tryParse(v ?? '');
                            //   if (n == null || n < 0) {
                            //     return 'Nieprawidłowa ilość';
                            //   }

                            //   if (isStock) {
                            //     final stockItem = stockItems.firstWhere(
                            //       (s) => s.id == itemRef,
                            //       orElse: () => StockItem(
                            //         id: '',
                            //         name: '',
                            //         description: '',
                            //         quantity: 0,
                            //       ),
                            //     );
                            //     final available = stockItem.quantity;
                            //     final takenBefore = existing?.previousQty ?? 0;
                            //     final delta = (n - takenBefore);
                            //     if (delta > available) {
                            //       final maxTotal = available + takenBefore;
                            //       return 'Za mało w magazynie (max: $maxTotal)';
                            //     }
                            //   }
                            //   return null;
                            // },
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              if (n == null || n <= 0)
                                return 'Serio? ...no jak?';

                              if (isStock) {
                                final available = selectedAvailable;
                                if (available <= 0) return 'Brak na stanie';
                                if (n > available)
                                  return 'Nie ma w magazynie (max: $available $unit)';
                              }
                              return null;
                            },

                            ////
                          ),

                          SizedBox(height: 24),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('Anuluj'),
                              ),

                              // Show SWAP button only when item exists in any RW
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

                              // -------------------- (kept for reference) --------------------
                              // if (isStock &&
                              //     itemRef.isNotEmpty &&
                              //     hasItemInAnyRW)
                              //   ElevatedButton(
                              //     onPressed: () async {
                              //       await Navigator.of(context).push(
                              //         MaterialPageRoute(
                              //           builder: (_) => SwapWorkflowScreen(
                              //             customerId: customerId,
                              //             projectId: projectId,
                              //             preselectedItemId: itemRef,
                              //             isAdmin: isAdmin,
                              //           ),
                              //         ),
                              //       );
                              //       if (ctx.mounted) {
                              //         Navigator.of(ctx).pop();
                              //       }
                              //     },
                              //     child: const Icon(
                              //       Icons.swap_horizontal_circle,
                              //       color: Color.fromARGB(255, 148, 115, 13),
                              //     ),
                              //   ),
                              // ElevatedButton(
                              //   onPressed: () {
                              //     if (!formKey.currentState!.validate()) return;
                              //     if (isStock && itemRef.isEmpty) {
                              //       ScaffoldMessenger.of(context).showSnackBar(
                              //         const SnackBar(content: Text('Wybierz produkt.')),
                              //       );
                              //       return;
                              //     }
                              //     final added = int.tryParse(qtyController.text.trim()) ?? 0;
                              //     if (added <= 0) {
                              //       ScaffoldMessenger.of(context).showSnackBar(
                              //         const SnackBar(content: Text('Wprowadź ilość > 0')),
                              //       );
                              //       return;
                              //     }
                              //     if (isStock) {
                              //       final available = selectedAvailable; // value set on scan/selection
                              //       if (available <= 0) {
                              //         ScaffoldMessenger.of(context).showSnackBar(
                              //           const SnackBar(content: Text('Brak na stanie — nie można dodać.')),
                              //         );
                              //         return;
                              //       }
                              //       if (added > available) {
                              //         ScaffoldMessenger.of(context).showSnackBar(
                              //           SnackBar(content: Text('Za mało w magazynie (max: $available $unit)')),
                              //         );
                              //         return;
                              //       }
                              //     }
                              //     final newQty = prevQty + added;
                              //     final int originalStock = isStock ? selectedAvailable : 0;
                              //     final line = ProjectLine(
                              //       isStock: isStock,
                              //       itemRef: itemRef,
                              //       customName: isStock ? '' : customController.text.trim(),
                              //       requestedQty: newQty,
                              //       unit: unit,
                              //       originalStock: originalStock,
                              //       previousQty: prevQty,
                              //       updatedAt: DateTime.now(),
                              //     );
                              //     Navigator.of(ctx).pop(line);
                              //   },
                              //   child: Text(existing == null ? 'Dodaj' : 'Zapisz'),
                              // ),
                              // ------------------ end kept commented block -------------------

                              // ✅ Always-visible DODAJ / ZAPISZ button
                              ElevatedButton(
                                onPressed: () async {
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
                                  if (added <= 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Wprowadź ilość > 0'),
                                      ),
                                    );
                                    return;
                                  }

                                  // Local availability guard
                                  if (isStock) {
                                    final available = selectedAvailable;
                                    if (available <= 0) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Brak na stanie — nie można dodać.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    if (added > available) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Za mało w magazynie (max: $available $unit)',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                  }

                                  final newQty = prevQty + added;

                                  // Reserve in WAPRO for stock items
                                  if (isStock) {
                                    try {
                                      await AdminApi.init();
                                      final email =
                                          FirebaseAuth
                                              .instance
                                              .currentUser
                                              ?.email ??
                                          'app';
                                      final r = await AdminApi.reserveUpsert(
                                        projectId: projectId,
                                        customerId: customerId,
                                        itemId: itemRef,
                                        qty: newQty,
                                        actorEmail: email,
                                      );

                                      if (context.mounted) {
                                        final after = r['available_after'];
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Zarezerwowano $newQty $unit • Dostępne po: $after',
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Rezerwacja nie powiodła się: $e',
                                            ),
                                          ),
                                        );
                                      }
                                      return;
                                    }
                                  }

                                  final int originalStock = isStock
                                      ? selectedAvailable
                                      : 0;
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

                                  if (ctx.mounted) {
                                    Navigator.of(ctx).pop(line);
                                  }
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
