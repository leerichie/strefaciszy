// lib/screens/item_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:strefa_ciszy/screens/scan_screen.dart';
import 'package:strefa_ciszy/utils/keyboard_utils.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';
import 'add_item_screen.dart';
// import 'edit_item_screen.dart';

import 'package:strefa_ciszy/services/api_service.dart';
import 'package:strefa_ciszy/models/stock_item.dart';

class ItemDetailScreen extends StatelessWidget {
  final String itemId;
  final bool isAdmin;
  const ItemDetailScreen({
    super.key,
    this.isAdmin = false,
    required this.itemId,
  });

  @override
  Widget build(BuildContext context) {
    const title = 'Szczegóły';

    return AppScaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Skanuj',
        onPressed: () async {
          final result = await Navigator.of(context)
              .push<Map<String, dynamic>?>(
                MaterialPageRoute(
                  builder: (_) =>
                      const ScanScreen(purpose: ScanPurpose.projectLine),
                ),
              );

          if (result != null && result['id'] is String) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => ItemDetailScreen(
                  itemId: result['id'] as String,
                  isAdmin: isAdmin,
                ),
              ),
            );
          }
        },
        child: const Icon(Icons.qr_code_scanner, size: 32),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      centreTitle: true,
      title: title,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(56),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: []),
        ),
      ),
      actions: const [Padding(padding: EdgeInsets.symmetric(horizontal: 8.0))],
      body: DismissKeyboard(
        child: FutureBuilder<StockItem?>(
          future: ApiService.fetchProduct(itemId),
          builder: (ctx, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final item = snapshot.data;
            if (item == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Nie znaleziono produktu'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AddItemScreen(initialBarcode: itemId),
                        ),
                      ),
                      child: const Text('Dodaj nowy produkt'),
                    ),
                  ],
                ),
              );
            }

            final qty = item.quantity;
            final unit = item.unit;
            final imageUrl = item.imageUrl;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrl != null && imageUrl.isNotEmpty) ...[
                    Center(
                      child: SizedBox(
                        width: double.infinity,
                        height: 150,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (ctx, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            },
                            errorBuilder: (ctx, error, stack) {
                              return Container(
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.broken_image,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Table(
                    columnWidths: const {0: IntrinsicColumnWidth()},
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      _row('Producent', item.producent),
                      _row('SKU', item.sku),
                      _row(
                        'Kategoria',
                        item.category.isNotEmpty
                            ? item.category
                            : item.description,
                      ),
                      _row('Magazyn', null),
                      _row('Kod Kreskowy', item.barcode),
                      _row('Ilość', '$qty${unit.isNotEmpty ? ' $unit' : ''}'),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Center(
                  //   child: ElevatedButton(
                  //     onPressed: isAdmin
                  //         ? () {
                  //             // Keep disabled until you wire API editing routes.
                  //             ScaffoldMessenger.of(context).showSnackBar(
                  //               const SnackBar(
                  //                 content: Text(
                  //                   'Edytowanie przez API jeszcze nieaktywne',
                  //                 ),
                  //               ),
                  //             );
                  //             // If you later enable:
                  //             // Navigator.of(context).push(
                  //             //   MaterialPageRoute(
                  //             //     builder: (_) => EditItemScreen(
                  //             //       item.id,
                  //             //       // pass any needed data
                  //             //       isAdmin: isAdmin,
                  //             //     ),
                  //             //   ),
                  //             // );
                  //           }
                  //         : null,
                  //     child: const Text('Edytuj szczegóły'),
                  //   ),
                  // ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

TableRow _row(String label, dynamic value) => TableRow(
  children: [
    Padding(
      padding: const EdgeInsets.only(right: 12, bottom: 4),
      child: Text(
        '$label:',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
    ),
    Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        value?.toString().isNotEmpty == true ? value.toString() : '—',
      ),
    ),
  ],
);
