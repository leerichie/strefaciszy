import 'package:flutter/material.dart';
import 'package:strefa_ciszy/utils/keyboard_utils.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';
import 'package:strefa_ciszy/screens/inventory_list_screen.dart';
import 'package:strefa_ciszy/widgets/stock_item_form.dart';

// 🔴 Firestore service (disabled)
// import '../services/stock_item_service.dart';

// ✅ API
import 'package:strefa_ciszy/services/api_service.dart';
import 'package:strefa_ciszy/models/stock_item.dart';

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
    // final service = StockItemService(); // 🔴 Firestore

    final initial = StockItemInitial(
      barcode: initialBarcode ?? '',
      name: initialName ?? '',
    );

    return AppScaffold(
      title: 'Dodaj',
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
                            // Read-only backend for now – no write to WAPRO
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'API w trybie tylko-do-odczytu. Dodawanie wyłączone.',
                                ),
                              ),
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
