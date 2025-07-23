import 'package:flutter/material.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';
import 'package:strefa_ciszy/screens/inventory_list_screen.dart';
import 'package:strefa_ciszy/widgets/stock_item_form.dart';
import '../services/stock_item_service.dart';

class AddItemScreen extends StatelessWidget {
  final String? initialBarcode;
  final String? initialName;
  const AddItemScreen({super.key, this.initialBarcode, this.initialName});

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
      barcode: initialBarcode ?? '',
      name: initialName ?? '',
    );

    return AppScaffold(
      title: 'Dodaj',
      centreTitle: true,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StockItemForm(
          initial: initial,
          onSubmit: (v) async {
            await service.addItem(
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
    );
  }
}
