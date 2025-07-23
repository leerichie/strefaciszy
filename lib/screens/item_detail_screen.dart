import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:strefa_ciszy/widgets/app_scaffold.dart';
import 'add_item_screen.dart';
import 'edit_item_screen.dart';

class ItemDetailScreen extends StatelessWidget {
  final String itemId;
  final bool isAdmin;
  const ItemDetailScreen({
    super.key,
    this.isAdmin = false,
    required this.itemId,
  });

  // Future<void> _changeQuantity(String docId, int delta, int currentQty) async {
  //   final newQty = currentQty + delta;
  //   if (newQty < 0) return;
  //   await FirebaseFirestore.instance
  //       .collection('stock_items')
  //       .doc(docId)
  //       .update({
  //         'quantity': newQty,
  //         'updatedAt': FieldValue.serverTimestamp(),
  //         'updatedBy': FirebaseAuth.instance.currentUser!.uid,
  //       });
  // }

  @override
  Widget build(BuildContext context) {
    final title = 'Szczegóły';
    return AppScaffold(
      centreTitle: true,
      title: title,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
              ],
            ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          // child: CircleAvatar(
          //   backgroundColor: Colors.black,
          //   child: IconButton(
          //     icon: const Icon(Icons.home),
          //     color: Colors.white,
          //     tooltip: 'Home',
          //     onPressed: () {
          //       Navigator.of(context).pushAndRemoveUntil(
          //         MaterialPageRoute(
          //           builder: (_) => const MainMenuScreen(role: 'admin'),
          //         ),
          //         (route) => false,
          //       );
          //     },
          //   ),
          // ),
        ),
      ],

      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('stock_items')
            .doc(itemId)
            .snapshots(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final doc = snapshot.data;
          if (doc == null || !doc.exists) {
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
          final data = doc.data()! as Map<String, dynamic>;
          final qty = data['quantity'] ?? 0;
          final unit = data['unit'] ?? '';
          final imageUrl = data['imageUrl'] as String?;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl != null) ...[
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
                  data['name'] ?? '—',
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
                    _row('Producent', data['producent']),
                    _row('SKU', data['sku']),
                    _row('Kategoria', data['category']),
                    _row('Magazyn', data['location']),
                    _row('Kod Kreskowy', data['barcode']),
                    _row('Ilość', data['quantity']),
                  ],
                ),

                Center(
                  child: ElevatedButton(
                    onPressed: isAdmin
                        ? () {
                            final data = doc.data()! as Map<String, dynamic>;
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => EditItemScreen(
                                  doc.id,
                                  data: data,
                                  isAdmin: isAdmin,
                                ),
                              ),
                            );
                          }
                        : null,
                    child: const Text('Edytuj szczegóły'),
                  ),
                ),
              ],
            ),
          );
        },
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
      child: Text(value?.toString() ?? '—'),
    ),
  ],
);
