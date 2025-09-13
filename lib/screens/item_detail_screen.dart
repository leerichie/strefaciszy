// lib/screens/item_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:strefa_ciszy/models/stock_item.dart';
import 'package:strefa_ciszy/screens/scan_screen.dart';
import 'package:strefa_ciszy/services/admin_api.dart'; // <-- NEW
import 'package:strefa_ciszy/services/api_service.dart';
import 'package:strefa_ciszy/utils/keyboard_utils.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';

import 'add_item_screen.dart';

class ItemDetailScreen extends StatelessWidget {
  final String itemId;
  final bool isAdmin;
  const ItemDetailScreen({
    super.key,
    this.isAdmin = false,
    required this.itemId,
  });

  // ---- EAN helpers (local) ----
  String _digitsOnly(String s) => s.replaceAll(RegExp(r'\D+'), '');
  bool _isValidEan(String? ean) {
    final d = _digitsOnly(ean ?? '');
    if (d.isEmpty) return false;
    if (!(d.length == 8 || d.length == 13)) return false;
    final nums = d.split('').map(int.parse).toList();
    final check = nums.removeLast();
    int sum = 0;
    if (d.length == 13) {
      for (int i = 0; i < nums.length; i++) {
        sum += (i % 2 == 0) ? nums[i] : nums[i] * 3;
      }
    } else {
      for (int i = 0; i < nums.length; i++) {
        sum += (i % 2 == 0) ? nums[i] * 3 : nums[i];
      }
    }
    final calc = (10 - (sum % 10)) % 10;
    return calc == check;
  }

  Future<void> _addEanFlow(BuildContext context, StockItem item) async {
    final ctrl = TextEditingController();
    String? chosen;

    Future<void> pickByScan() async {
      // only return the raw code; do NOT search
      final code = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => const ScanScreen(
            returnCode: true,
            titleText: 'Skanuj EAN (ustaw)',
          ),
        ),
      );
      if (!context.mounted) return;
      if (code != null && code.isNotEmpty) {
        final digits = _digitsOnly(code);
        ctrl.text = digits;
        chosen = digits;
      }
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dodaj EAN'),
        content: TextFormField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: '8 lub 13 cyfr',
            suffixIcon: IconButton(
              tooltip: 'Skanuj',
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: pickByScan,
            ),
          ),
          onChanged: (v) => chosen = _digitsOnly(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    chosen = _digitsOnly(chosen ?? ctrl.text);
    if (!_isValidEan(chosen)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nieprawidłowy EAN (8 lub 13 cyfr).')),
      );
      return;
    }

    try {
      await AdminApi.setProductEan(id: item.id, ean: chosen!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('EAN zapisany: $chosen'),
          duration: const Duration(seconds: 2),
        ),
      );
      // Optional refresh of the details screen:
      // if (!context.mounted) return;
      // Navigator.of(context).pushReplacement(
      //   MaterialPageRoute(
      //     builder: (_) => ItemDetailScreen(itemId: item.id, isAdmin: isAdmin),
      //   ),
      // );
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 6)),
      );
    }
  }

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
                  builder: (_) => const ScanScreen(purpose: ScanPurpose.search),
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

            final barcode = item.barcode.trim();
            final hasValidEan = _isValidEan(barcode);
            final needsEan = !hasValidEan;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: SelectionArea(
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
                    const SizedBox(height: 4),
                    Text(
                      'WAPRO id_artykulu: ${item.id}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        height: 1.2,
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 8),

                    Table(
                      columnWidths: const {0: IntrinsicColumnWidth()},
                      defaultVerticalAlignment:
                          TableCellVerticalAlignment.middle,
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
                        _row('Kod Kreskowy', hasValidEan ? barcode : '—'),
                        _row('Ilość', '$qty${unit.isNotEmpty ? ' $unit' : ''}'),
                      ],
                    ),

                    const SizedBox(height: 16),

                    if (needsEan)
                      Center(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Dodaj EAN'),
                          onPressed: () => _addEanFlow(context, item),
                        ),
                      ),

                    // (keep any other admin buttons disabled for now)
                  ],
                ),
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
