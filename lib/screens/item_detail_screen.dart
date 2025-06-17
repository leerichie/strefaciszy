import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_item_screen.dart';
import 'edit_item_screen.dart';

class ItemDetailScreen extends StatelessWidget {
  final String itemId;
  const ItemDetailScreen({Key? key, required this.itemId}) : super(key: key);

  Future<void> _changeQuantity(String docId, int delta, int currentQty) async {
    final newQty = currentQty + delta;
    if (newQty < 0) return;
    await FirebaseFirestore.instance
        .collection('stock_items')
        .doc(docId)
        .update({
          'quantity': newQty,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': FirebaseAuth.instance.currentUser!.uid,
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Szczegóły')),
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
                  Center(child: Image.network(imageUrl, height: 150)),
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
                    _row('SKU', data['sku']),
                    _row('Producent', data['producent']),
                    _row('Kategoria', data['category']),
                    _row('Magazyn', data['location']),
                    _row('Kod Kreskowy', data['barcode']),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      'Ilość ($unit):',
                      style: const TextStyle(fontSize: 18),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: () => _changeQuantity(doc.id, -1, qty),
                    ),
                    Text('$qty', style: const TextStyle(fontSize: 18)),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => _changeQuantity(doc.id, 1, qty),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EditItemScreen(doc.id, data: data),
                      ),
                    ),
                    child: const Text('Edytuj szczegoly'),
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
        label + ':',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
    ),
    Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(value?.toString() ?? '—'),
    ),
  ],
);
