import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Inventory')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('stock_items')
            .orderBy('name')
            .snapshots(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading inventory:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red),
              ),
            );
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(child: Text('No items in stock.'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final data = docs[i].data()! as Map<String, dynamic>;
              return ListTile(
                title: Text(data['name'] ?? '—'),
                subtitle: Text('Qty: ${data['quantity'] ?? 0}'),
                trailing: Text(data['barcode'] ?? ''),
                onTap: () {
                  // TODO: navigate to detail/edit screen
                },
              );
            },
          );
        },
      ),
    );
  }
}
