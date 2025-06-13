import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_item_screen.dart';
import 'edit_item_screen.dart'; // we’ll build this later

class ItemDetailScreen extends StatelessWidget {
  final String code;
  const ItemDetailScreen({super.key, required this.code});

  Future<QuerySnapshot> _fetchItem() {
    return FirebaseFirestore.instance
        .collection('stock_items')
        .where('barcode', isEqualTo: code)
        .limit(1)
        .get();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Product Details')),
      body: FutureBuilder<QuerySnapshot>(
        future: _fetchItem(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error loading item:\n${snap.error}'));
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            // No item found: offer to create
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'No product found for\n“$code”',
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Jump to AddItemScreen with code prefilled
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AddItemScreen(initialBarcode: code),
                        ),
                      );
                    },
                    child: Text('Add New Product'),
                  ),
                ],
              ),
            );
          }
          // We found one product
          final doc = docs.first;
          final data = doc.data()! as Map<String, dynamic>;
          return Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['name'] ?? '—',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('SKU: ${data['sku'] ?? '—'}'),
                Text('Category: ${data['category'] ?? '—'}'),
                Text('Location: ${data['location'] ?? '—'}'),
                Text('Barcode: ${data['barcode'] ?? '—'}'),
                SizedBox(height: 16),
                Row(
                  children: [
                    Text('Quantity:', style: TextStyle(fontSize: 18)),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.remove),
                      onPressed: () {
                        // TODO: decrement quantity
                      },
                    ),
                    Text(
                      '${data['quantity'] ?? 0}',
                      style: TextStyle(fontSize: 18),
                    ),
                    IconButton(
                      icon: Icon(Icons.add),
                      onPressed: () {
                        // TODO: increment quantity
                      },
                    ),
                  ],
                ),
                SizedBox(height: 24),
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: navigate to full-edit screen
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EditItemScreen(doc.id, data: data),
                        ),
                      );
                    },
                    child: Text('Edit Details'),
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
