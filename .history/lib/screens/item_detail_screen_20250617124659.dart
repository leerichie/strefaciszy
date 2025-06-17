// lib/screens/item_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'add_item_screen.dart';
import 'edit_item_screen.dart';

class ItemDetailScreen extends StatelessWidget {
  /// *Same* parameter name as before – nothing else in the app needs changing.
  final String code;
  const ItemDetailScreen({super.key, required this.code});

  // live stream of the product found by barcode
  Stream<QuerySnapshot<Map<String, dynamic>>> _itemStream() {
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

  // neat “label : value” row with a little spacing
  Widget _detailRow({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(label)),
          const SizedBox(width: 8),
          Expanded(flex: 4, child: Text(value.isEmpty ? '—' : value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Szczegóły')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _itemStream(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Błąd: ${snap.error}'));
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Nie znaleziono:\n“$code”', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    child: const Text('Dodaj nowy produkt'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AddItemScreen(initialBarcode: code),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final doc = docs.first;
          final data = doc.data();
          final qty = data['quantity'] ?? 0;
          final unit = data['unit'] ?? '';
          final imageUrl = data['imageUrl'] as String?;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                if (imageUrl != null && imageUrl.isNotEmpty) ...[
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
                const SizedBox(height: 12),

                _detailRow(label: 'SKU:', value: data['sku'] ?? ''),
                _detailRow(label: 'Kategoria:', value: data['category'] ?? ''),
                _detailRow(label: 'Magazyn:', value: data['location'] ?? ''),
                _detailRow(
                  label: 'Kod kreskowy:',
                  value: data['barcode'] ?? '',
                ),

                const SizedBox(height: 16),

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
                    child: const Text('Edytuj szczegóły'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EditItemScreen(doc.id, data: data),
                      ),
                    ),
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
