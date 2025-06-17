// lib/screens/item_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_item_screen.dart';
import 'edit_item_screen.dart';

class ItemDetailScreen extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  const ItemDetailScreen({super.key, required this.code});

  Stream<QuerySnapshot> _fetchItem() {
    return FirebaseFirestore.instance
        .collection('stock_items')
        .where('barcode', isEqualTo: code)
        .limit(1)
        .snapshots();
  }

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
      body: StreamBuilder<QuerySnapshot>(
        stream: _fetchItem(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Nie znaleziono:\n“$code”', textAlign: TextAlign.center),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AddItemScreen(initialBarcode: code),
                      ),
                    ),
                    child: Text('Dodaj nowy produkt'),
                  ),
                ],
              ),
            );
          }

          final doc = docs.first;
          final data = doc.data()! as Map<String, dynamic>;
          final qty = data['quantity'] ?? 0;
          final unit = data['unit'] ?? '';
          final imageUrl = data['imageUrl'] as String?;

          return Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl != null) ...[
                  Center(child: Image.network(imageUrl, height: 150)),
                  SizedBox(height: 16),
                ],
                Text(
                  data['name'] ?? '—',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Table(
                  columnWidths: const {0: IntrinsicColumnWidth()},
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    _row('SKU', data['sku']),
                    _row('Kategoria', data['category']),
                    _row('Magazyn', data['location']),
                    _row('Kod Kreskowy', data['barcode']),
                  ],
                ),

                Row(
                  children: [
                    Text('Ilość ($unit):', style: TextStyle(fontSize: 18)),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.remove),
                      onPressed: () => _changeQuantity(doc.id, -1, qty),
                    ),
                    Text('$qty', style: TextStyle(fontSize: 18)),
                    IconButton(
                      icon: Icon(Icons.add),
                      onPressed: () => _changeQuantity(doc.id, 1, qty),
                    ),
                  ],
                ),

                SizedBox(height: 24),
                Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EditItemScreen(doc.id, data: data),
                      ),
                    ),
                    child: Text('Edytuj szczegoly'),
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
