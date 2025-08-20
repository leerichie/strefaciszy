import 'package:flutter/material.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';
import 'package:strefa_ciszy/screens/inventory_list_screen.dart';
import 'package:strefa_ciszy/widgets/stock_item_form.dart';
import '../utils/keyboard_utils.dart';

// 🔴 Firestore service (disabled for API mode)
// import '../services/stock_item_service.dart';

// ✅ API
import 'package:strefa_ciszy/services/api_service.dart';
import 'package:strefa_ciszy/models/stock_item.dart';

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
    // final service = StockItemService(); // 🔴 Firestore

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
                            // Read-only backend for now – no write to WAPRO
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'API w trybie tylko-do-odczytu. Edycja wyłączona.',
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
