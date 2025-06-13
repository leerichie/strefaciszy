// lib/screens/item_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_item_screen.dart';
import 'edit_item_screen.dart';

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

  Future<void> _changeQuantity(
    BuildContext context,
    String docId,
    int delta,
    int currentQty,
  ) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final newQty = currentQty + delta;
    if (newQty < 0) return;
    await FirebaseFirestore.instance
        .collection('stock_items')
        .doc(docId)
        .update({
          'quantity': newQty,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': uid,
        });
    // Refresh the screen
    Navigator.of(context).pop();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ItemDetailScreen(code: code)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Product Details')),
      // 1) SafeArea makes sure we stay out of the nav bars
      body: SafeArea(
        // 2) FutureBuilder stays the same
        child: FutureBuilder<QuerySnapshot>(
          future: _fetchItem(),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Error loading item:\n${snap.error}'));
            }

            final docs = snap.data!.docs;
            // 3) If no item, show a scrollable "add" UI
            if (docs.isEmpty) {
              return SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'No product found for\n“$code”',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
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

            // 4) If we found it, show the details in a scroll view
            final doc = docs.first;
            final data = doc.data()! as Map<String, dynamic>;
            final qty = data['quantity'] ?? 0;
            return SingleChildScrollView(
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
                        onPressed: () =>
                            _changeQuantity(context, doc.id, -1, qty),
                      ),
                      Text('$qty', style: TextStyle(fontSize: 18)),
                      IconButton(
                        icon: Icon(Icons.add),
                        onPressed: () =>
                            _changeQuantity(context, doc.id, 1, qty),
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
                      child: Text('Edit Details'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
