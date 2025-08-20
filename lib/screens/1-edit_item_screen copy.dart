import 'package:flutter/material.dart';
import 'package:strefa_ciszy/screens/1-inventory_list_screen.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';
import 'package:strefa_ciszy/widgets/stock_item_form.dart';
import '../services/stock_item_service.dart';
import '../utils/keyboard_utils.dart';

class EditItemScreen extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final bool isAdmin;

  const EditItemScreen(
    this.docId, {
    super.key,
    required this.data,
    this.isAdmin = false,
  });

  void _goToInventory(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => InventoryListScreen(isAdmin: true)),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = StockItemService();
    final initial = StockItemInitial(
      name: data['name'] ?? '',
      sku: data['sku'] ?? '',
      barcode: data['barcode'] ?? '',
      producent: data['producent'] ?? '',
      category: data['category'] ?? '',
      quantity: (data['quantity'] ?? 0) as int,
      unit: data['unit'] ?? 'szt',
      location: data['location'] ?? '',
      imageUrl: data['imageUrl'] as String?,
    );

    return AppScaffold(
      title: 'Edytuj produkt',
      centreTitle: true,
      body: DismissKeyboard(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      Expanded(
                        child: StockItemForm(
                          initial: initial,
                          onSubmit: (v) async {
                            await service.updateItem(
                              docId: docId,
                              name: v.name,
                              sku: v.sku,
                              barcode: v.barcode,
                              producent: v.producent,
                              category: v.category,
                              quantity: v.quantity,
                              unit: v.unit,
                              location: v.location,
                              imageFile: v.imageFile,
                            );
                            _goToInventory(context);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
